plugin "terraform" {
    enabled = true
    preset  = "recommended"
}

plugin "aws" {
    enabled = google
    version = "0.34.0"
    source  = "github.com/terraform-linters/tflint-ruleset-google"
}
