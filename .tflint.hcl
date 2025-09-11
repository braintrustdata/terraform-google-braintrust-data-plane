plugin "terraform" {
    enabled = true
    preset  = "recommended"
}

plugin "google" {
    enabled = true
    version = "0.35.0"
    source  = "github.com/terraform-linters/tflint-ruleset-google"
}

rule "google_container_node_pool_invalid_machine_type" {
    enabled = false
}
