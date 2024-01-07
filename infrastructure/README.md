# Region Manager Infrastructure

This directory contains the [Terraform](https://www.terraform.io/) infrastructure-as-code (IaC) files for almost all of the infrastructure necessary to run the _Region Manager_ application.

## Included Files

Here is a brief overview of what you can find in here:

* `az_ses/` is a Terraform submodule that defines infrastructure in Amazon Web Services (AWS) for sending email through their Simple Email Service (SES).
* `do_mx_google/` is a Terraform submodule that defines domain records for receiving email for `@ftcregion.com` using Google Workspace (GMail).
* `app.tf` defines the DigitalOcean App Platform instance for the application and all of its environment variables.
* `database.tf` defines the hosted database and its user.
* `domain.tf` defines the domain records for `ftcregion.com`.
* `email.tf` defines the email sending infrastructure.
* `main.tf` defines the Terraform providers and all of the variables.
* `network.tf` defines the application's Virtual Private Cloud network and firewall rules.
* `space.tf` defines the DigitalOcean Spaces object storage bucket.

## Not Included

There are several important files not committed here.

* `.terraform/` is a directory created when running `terraform init` that contains copies of the provider libraries and other programmatically generated stuff.
* `backend_override.tf` is an optional file for overriding where Terraform's state is stored.
  By default, it will be stored in `.tfstate` files in this directory.
  It is possible to store it in a centralized location as well.
* `ca-certificate.crt` is the CA certificate bundle given by DigitalOcean for its hosted database.
  This file is used as an environment variable `rm_database_cacert`.
* `secrets.auto.tfvars` contains all of the secrets used by the rest of the code.
  Each secret is declared as a `variable` in `main.tf`.

## Starting from Scratch

If you're using these files to get up-and-running, here are some tips:

1. Start by creating `secrets.auto.tfvars`.
  Create an entry in this file for any `variable` listed in `main.tf` that does not already have a value.
  There are comments explaining the source and format of each variable.
2. Install Terraform.
3. Run `terraform init`.
4. Run `terraform apply`.
  You may need to do this several times (for example, once to create the managed database, and once to apply the environment variable containing the database's CA certificate).

Even if you don't intend to use these IaC files directly, they provide a manifest of the pieces of infrastructure necessary to run _Region Manager_.
