terraform {
    backend "s3" {
        bucket = "task3-tfstate-687078156188-us-east-1"
        key = "task3/terraform.tfstate"
        region = "us-east-1"
        use_lockfile = true
    }
}