# =============================================================================
# Backend distant, état Terraform dans S3 avec verrouillage DynamoDB.
#
# Les valeurs (bucket, table, clé) sont volontairement laissées vides ici et
# fournies à l'initialisation via un fichier de backend ou des options -backend-config :
#
#   terraform init \
#     -backend-config="bucket=mon-bucket-tfstate" \
#     -backend-config="key=02-webapp-3tier-ha/terraform.tfstate" \
#     -backend-config="region=eu-west-3" \
#     -backend-config="dynamodb_table=terraform-locks"
#
# Cela évite de coder en dur des identifiants d'infrastructure dans le dépôt.
# =============================================================================

terraform {
  backend "s3" {
    # bucket         = "<à fournir via -backend-config>"
    # key            = "02-webapp-3tier-ha/terraform.tfstate"
    # region         = "<à fournir via -backend-config>"
    # dynamodb_table = "<à fournir via -backend-config>"
    encrypt = true
  }
}
