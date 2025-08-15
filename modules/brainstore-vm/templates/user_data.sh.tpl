#!/bin/bash

# Help prevent immediate failure of apt commands if another background process is holding the lock
echo 'DPkg::Lock::Timeout "60";' > /etc/apt/apt.conf.d/99apt-lock-retry

# Mount the local SSD if it exists
apt-get update
apt-get install -y nvme-cli
MOUNT_DIR="/mnt/tmp/brainstore"
mkdir -p "$MOUNT_DIR"
# GCP local SSDs are typically at /dev/nvme0n1 or similar
DEVICE=$(nvme list | grep 'Google EphemeralDisk' | head -n1 | awk '{print $1}')
if [ -z "$DEVICE" ]; then
  # Fallback to checking common GCP local SSD paths
  for dev in /dev/nvme0n1 /dev/sdb /dev/disk/by-id/google-local-ssd-0; do
    if [ -b "$dev" ]; then
      DEVICE="$dev"
      break
    fi
  done
fi

if [ -n "$DEVICE" ]; then
  echo "Local SSD device: $DEVICE"
  blkid "$DEVICE" >/dev/null || mkfs.ext4 -F "$DEVICE"
  mount "$DEVICE" "$MOUNT_DIR"
  # Add to fstab using UUID rather than device name
  UUID=$(blkid -s UUID -o value "$DEVICE")
  echo "UUID=$UUID $MOUNT_DIR ext4 defaults 0 2" >> /etc/fstab
else
  echo "No local SSD found. Exiting with failure."
  exit 1
fi

# Raise the file descriptor limit
cat <<EOF > /etc/security/limits.d/brainstore.conf
# Root users has to be set explicitly
root soft nofile 65535
root hard nofile 65535
# All other users
* soft nofile 65535
* hard nofile 65535
EOF

# Set up docker log rotation
mkdir -p /etc/docker
cat <<EOF > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

apt-get install -y docker.io jq earlyoom dstat
systemctl start docker
systemctl enable docker

# Install Google Cloud Ops Agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Configure Google Cloud Ops Agent for structured logging
cat <<EOF > /etc/google-cloud-ops-agent/config.yaml
logging:
  receivers:
    brainstore_logs:
      type: files
      include_paths:
        - /var/lib/docker/containers/*/*.log
      record_log_file_path: true

  exporters:
    brainstore_logs_exporter:
      type: google_cloud_logging
      log_name: containers
      resource:
        type: generic_node
        labels:
          namespace: brainstore
          deployment: ${deployment_name}

  service:
    pipelines:
      brainstore_pipeline:
        receivers: [brainstore_logs]
        exporters: [brainstore_logs_exporter]
EOF

# Restart Ops Agent to pick up new configuration
systemctl restart google-cloud-ops-agent

# Get database credentials from Secret Manager
DB_CREDS=$(gcloud secrets versions access latest --secret="${database_secret_name}")
DB_USERNAME=$(echo $DB_CREDS | jq -r .username)
DB_PASSWORD=$(echo $DB_CREDS | jq -r .password)

BRAINSTORE_LICENSE_KEY=$(gcloud secrets versions access latest --secret="${brainstore_license_key_secret_name}")

cat <<EOF > /etc/brainstore.env
# WARNING: Do NOT use quotes around values here. They get passed as literals by docker.
BRAINSTORE_VERBOSE=1
BRAINSTORE_PORT=${brainstore_port}
BRAINSTORE_INDEX_URI=gs://${brainstore_gcs_bucket}/brainstore/index
BRAINSTORE_REALTIME_WAL_URI=gs://${brainstore_gcs_bucket}/brainstore/wal
BRAINSTORE_LOCKS_URI=redis://${redis_host}:${redis_port}
BRAINSTORE_METADATA_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres?sslmode=require
BRAINSTORE_WAL_URI=postgres://$DB_USERNAME:$DB_PASSWORD@${database_host}:${database_port}/postgres?sslmode=require
BRAINSTORE_CACHE_DIR=/mnt/tmp/brainstore
BRAINSTORE_LICENSE_KEY=$BRAINSTORE_LICENSE_KEY
BRAINSTORE_DISABLE_OPTIMIZATION_WORKER=${brainstore_disable_optimization_worker}
BRAINSTORE_VACUUM_OBJECT_ALL=${brainstore_vacuum_all_objects}
NO_COLOR=1
%{ for env_key, env_value in extra_env_vars ~}
${env_key}=${env_value}
%{ endfor ~}
EOF

if [ "${is_dedicated_writer_node}" = "true" ]; then
  # Until we are comfortable with stability
  echo '0 * * * * root /usr/bin/docker restart brainstore > /var/log/brainstore-restart.log 2>&1' > /etc/cron.d/restart-brainstore
fi

if [ -n "${internal_observability_api_key}" ]; then
  if [ -n "${internal_observability_env_name}" ]; then
    export DD_ENV="${internal_observability_env_name}"
  fi
  # Install Datadog Agent
  export DD_API_KEY="${internal_observability_api_key}"
  export DD_SITE="${internal_observability_region}.datadoghq.com"
  export DD_APM_INSTRUMENTATION_ENABLED=host
  export DD_APM_INSTRUMENTATION_LIBRARIES=java:1,python:3,js:5,php:1,dotnet:3
  bash -c "\$(curl -L https://install.datadoghq.com/scripts/install_script_agent7.sh)"
  usermod -a -G docker dd-agent

  cat <<EOF > /etc/datadog-agent/environment
DD_OTLP_CONFIG_RECEIVER_PROTOCOLS_HTTP_ENDPOINT=0.0.0.0:4318
DD_COLLECT_EC2_TAGS=true
DD_COLLECT_EC2_TAGS_USE_IMDS=true
EOF
  # Configure Datadog Agent to collect Docker logs
  cat <<EOF >> /etc/datadog-agent/datadog.yaml
logs_enabled: true
listeners:
    - name: docker
config_providers:
    - name: docker
      polling: true
logs_config:
    container_collect_all: true
EOF
  # Configure Brainstore to send traces to Datadog
  cat <<EOF >> /etc/brainstore.env
BRAINSTORE_OTLP_HTTP_ENDPOINT=http://localhost:4318
EOF
  # Restart Datadog Agent to pick up new configuration
  systemctl restart datadog-agent
fi

BRAINSTORE_RELEASE_VERSION=${brainstore_release_version}
BRAINSTORE_VERSION_OVERRIDE=${brainstore_version_override}
BRAINSTORE_VERSION=$${BRAINSTORE_VERSION_OVERRIDE:-$${BRAINSTORE_RELEASE_VERSION}}

docker run -d \
  --network host \
  --name brainstore \
  --env-file /etc/brainstore.env \
  --restart always \
  -v /mnt/tmp/brainstore:/mnt/tmp/brainstore \
  public.ecr.aws/braintrust/brainstore:$${BRAINSTORE_VERSION} \
  web