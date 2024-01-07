# Up and Running

This guide contains information for running the application in development and production.

## Development

_Region Manager_ is written in the [Elixir](https://elixir-lang.org) programming language using the [Phoenix](https://www.phoenixframework.org/) web framework.
While this is not the most popular "stack" in the web community, it provides an extremely flexible and rapid development experience on top of a well-tested runtime.

### Language and Runtime

To get started, you'll need to install the Elixir language and the Erlang runtime.
The best way to do this is using a version manager called ASDF.
For instructions on installing ASDF and its plugins, start [here](https://thinkingelixir.com/install-elixir-using-asdf/).
Here's an overview of the steps:

1. Install [asdf](https://github.com/asdf-vm/asdf)
2. Install the [asdf-erlang](https://github.com/asdf-vm/asdf-erlang) and [asdf-elixir](https://github.com/asdf-vm/asdf-elixir)
3. Clone this repository
4. Run `asdf install` in the root of the repository

Used versions of the Elixir language and Erlang runtime are saved in the `.tool-versions` file.
ASDF will automatically select these versions when you run `asdf install`.

### Database

_Region Manager_ uses a PostgreSQL database.
There are many ways to install PostgreSQL depending on which operating system you use.
On macOS, try [Postgres.app](https://postgresapp.com/) or installing it with [Homebrew](https://wiki.postgresql.org/wiki/Homebrew).

Regardless of the method of installation, _Region Manager_ will connect to the database using the information contained in the `config :rm, RM.Repo` section of `config/dev.exs`.
This usually means running Postgres on its default port of `5432` with a user/password combination of `postgres`/`postgres`.

Once the database is up and running, use `mix ecto.setup` in the root of this project to create the database and all of the tables.

### Dependencies

This application uses a number of third-party dependencies in the form of Elixir (Hex) packages.
Install these packages by running `mix deps.get` in the root of the project.

Here's an overview of the main dependencies:

* [Phoenix](https://www.phoenixframework.org/) is a web framework that, with the help of other packages, manages the request-to-response cycle, rendering templates, and real-time features.
* [Ecto](https://github.com/elixir-ecto/ecto) is a data mapping / database interface library.
* [Identity](https://github.com/aj-foster/identity) is an authentication helper library that handles logins, 2FA, password resets, email confirmation, and other user settings.
* [Swoosh](https://github.com/swoosh/swoosh) and its adapters manage the sending of email.
* [Waffle](https://github.com/elixir-waffle/waffle) is an object storage interface that connects to Amazon S3 and compatible storage services.

### Running

With the prerequisites and dependencies installed, use `mix phx.server` to start the application.
If you would like to have an interactive console to the application at the same time, use `iex -S mix phx.server`.

_Region Manager_ runs on port `4000`, and is therefore accessible at `http://localhost:4000` in development.

## Production

This section describes how the application is run _today_, which naturally describes the pieces of infrastructure necessary to run it elsewhere.

Almost all of the infrastructure was originally set up using [Terraform](https://www.terraform.io/), a way of defining infrastructure as code.
That code is committed to this repository in the `infrastructure` directory.
Even if you plan to set up the infrastructure manually, the files committed there can act as a manifest of everything that needs to be created.
See the [readme](../infrastructure/README.md) for more information.

### Application

_Region Manager_ runs on DigitalOcean's App Platform.
This means the application must be packaged into a Docker image and deployed to the platform.
Building and deploying is done by a [GitHub Actions workflow](../.github/workflows/ci.yml).

As with most applications, _Region Manager_ requires a number of environment variables.
These are defined in the Terraform using secret values not committed in this repository.

In production, the application serves requests on port `4000`.
It does not handle TLS connections, and instead expects that the App Platform will terminate TLS.
App Platform also handles the creation of TLS certificates.

### Database

_Region Manager_ uses a managed PostgreSQL database on DigitalOcean.
It generally utilizes the latest version available.

Database schema changes are managed automatically using migrations.
You can see the migration files in `priv/repo/migrations`.
The application will automatically migrate "up" when it starts up.

### Email

The application can send transactional email using Amazon Web Services' Simple Email Service (AWS SES).
This service requires some careful setup, and it requires ongoing maintenance of sender reputation.

Swoosh, the library that sends email, has adapters for a number of email sending services.
This means it should be straightforward to switch to another one.

In addition to sending email, the infrastructure included in this repository contains records for receiving email using Google Workspace.
Receiving email is necessary for bounce notifications from SES.

### Object Storage

_Region Manager_ uses S3-compatible object storage for saving files, such as uploads.
This is currently provided by DigitalOcean Spaces.

If an alternative storage provider is also S3-compatible, integration can be accomplished by reconfiguring `waffle` and `ex_aws` to use the provider's host and credentials.
If the provider is not S3-compatible, it may still be useable thanks to another adapter for Waffle, the library that manages storage.
