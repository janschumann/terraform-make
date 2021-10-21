terraform {
  backend "s3" {
    bucket         = "${state_bucket}"
    kms_key_id     = "${state_kms_key_id}"
    region         = "${state_region}"
    encrypt        = ${state_encrypt}
    acl            = "${state_acl}"
    dynamodb_table = "${state_lock_table}"
    key            = "" # set by cli param
    profile        = "" # set by cli param
  }
}
