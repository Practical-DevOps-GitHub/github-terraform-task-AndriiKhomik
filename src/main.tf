terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Initialize the GitHub provider
provider "github" {
  # owner = var.github_organization
  token = var.token
}

# Define the repository
resource "github_repository" "repo" {
  name        = var.repository_name
  description = "Repository for Terraform managed settings"
  visibility  = "public"
}

# Add collaborator to the repository
resource "github_repository_collaborator" "collabprator" {
  repository = github_repository.repo.name
  username   = var.username
  permission = var.collabprator_permission
}

# Create and protect the 'develop' branch
resource "github_branch" "develop" {
  repository = github_repository.repo.name
  branch     = var.branch
}

resource "github_branch_protection" "develop_protection" {
  repository_id = github_repository.repo.node_id
  pattern       = var.branch

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 2
  }
}

# Create and protect the 'main' branch
resource "github_branch_protection" "main_protection" {
  repository_id = github_repository.repo.node_id
  pattern       = "main"

  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    require_code_owner_reviews      = true
    required_approving_review_count = 1
  }
}

# Define code owners for the main branch
resource "github_repository_file" "codeowners" {
  repository = github_repository.repo.name
  file       = "./github/CODEOWNERS"
  content    = "* @softservedata"
  branch     = "main"
}

# Add pull request template
resource "github_repository_file" "pull_request_template" {
  repository = github_repository.repo.name
  file       = ".github/pull_request_template.md"
  content    = <<EOF
    ## Describe your changes
    ## Issue ticket number and link
    ## Checklist before requesting a review:
    - [ ] I have performed a self-review of my code
    - [ ] If it is a core feature, I have added thorough tests
    - [ ] Do we need to implement analytics?
    - [ ] Will this be part of a product update? If yes, please write one phrase about this update
  EOF
  branch     = var.branch
}

# Generate an ssh key using provider "hashicorp/tls"
resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

# Add the ssh key as a deploy key
resource "github_repository_deploy_key" "repository_deploy_key" {
  title      = "Repository deploy key"
  repository = github_repository.repo.name
  key        = tls_private_key.deploy_key.public_key_openssh
  read_only  = true
}

# Add a PAT secret to GitHub Actions
# resource "github_actions_secret" "pat" {
#   repository  = github_repository.repo.name
#   secret_name = "PAT"
#   plaintext_value = var.pat_token
# }

# Store the Terraform code as a repository secret
# resource "github_actions_secret" "terraform_code" {
#   repository      = github_repository.repo.name
#   secret_name     = "TERRAFORM"
#   plaintext_value = filebase64("${path.module}/terraform.tf")
# }

# Discord server webhook
resource "github_repository_webhook" "discord_pr_notification" {
  repository = github_repository.repo.name

  configuration {
    url          = "https://softserveinc.com/"
    content_type = "json"
  }

  events = ["pull_request"]
}
