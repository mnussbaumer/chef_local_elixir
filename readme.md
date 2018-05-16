*Use at will;;*

A group of recipes to automate server provisioning for Elixir on Ubuntu.
These recipes work at least on AWS EC2 instances with the regular Ubuntu Image and Scaleway servers with their Ubuntu Images.

In Scaleway you need to install bzip2 before using them, so that the tar can be unpacked.
ssh'ing as root then running
`apt-get install bzip2`

In both cases you need to have the instance be accessible through SSH, and for the running server, in the case of AWS EC2 you need to have that instance allow inbound traffic for HTTP (& HTTPS if you wish to use SSL)

This was part of my ongoing learning of DevOps. I had spent some time reading about Docker, Ansible and Chef. Since I was familiar with Ruby, Docker seemed a bit too complex to grasp at once and Ansible didn't provide anything more than either the other two options, I decided to do it using Chef - because in this mode it suited well small server setups but the knowledge of its dsl would still be meaningful if wanted to develop further skills in DevOps by providing a rich system for managing complex clusters.

Chef is intended for large scale system administration with several nodes, with an online instance working as central repository/command center (actually powered by Erlang) but before it did provide a `chef-solo` mode (now deprecated) and currently provides a way of running the client with a local flag, which in turn makes it similar to Ansible and a great option to manage small servers rigs.

The way to use this repo is to download it as a zip, then unzip it into a folder, name it accordingly and customise the `environment` file (and any other recipes or templates inside) for each servers setup you wish to use. Then unzip it once more if you want to add a new server setup and so on.

These recipes assume you're using `e-deliver` with `distillery` to build your Elixir Apps. They're also intended to be used with a build server and a production server, although I'm almost positive you can run both recipes on the same server and use that as both the build and production server. They also install chefdk for running the recipes.

Besides that it includes recipes for setting up Postgresql, Letsencrypt and the proper configuration for Nginx with SSL. It installs emacs as well with a default useful configuration and packages on the servers.

It also assumes the creation of a user for it, usually "deploy" but you can name it anything. The cool thing, is that all of that is basically controlled by a single file. If for nothing else you can check both the recipes, to see the logic for provisioning the server, and the templates, for examples of how to configure certain files (nginx, systemd, etc). One detail is that it the elixir config prod.secret.exs file assumes you're using bamboo, you'll need to edit that template in case you don't or your probably won't be able to run the build as bamboo will be missing and won't be configurable.

As an example of how you would provision a build server in EC2:

`./deploy_kitchen.sh ubuntu@your_instance_address 'recipe[elixir_web::build_server]'`

Now you're ready to just put your instance address on your e-deliver config and build a release there. This server will have Erlang 20.1 installed and Elixir, Git, Yarn, Node, and build-essential package, a user named whatever you like, a swap enable bash script, a proper `.profile` file exporting all your env variables and a `prod.secret.exs` file accessible to the distillery release builder. 

You pass the options for the recipes you want to run (or none if you want the default production server only) as a comma separated argument to the `./deploy_kitchen.sh` script. This in turn packs your current directory into a tar and uploads it to the server (hence you don't even need to commit the changes to any files, since they'll be packed fresh whenever you run the deploy_kitchen script), then calls `install.sh` to install the chefdk client on the server and run the recipes you named. In the process it sources the environment file as environment variables to the bash sessions running, so that they're accessible through the recipes. 

It also makes it easy to ensure parity between the build server environment and the production server. And because its idempotent you can use the same build server for different apps, by just running the build_server recipe once with an environment file (which will replace the environment, source it, and replace the prod.secret.exs file if they've changed) and then repeat again from a different directory with different environment files.


To provision a production server for running your elixir web app you would simply run:

./deploy_kitchen.sh ubuntu@your_instance_address

or

./deploy_kitchen.sh ubuntu@your_instance_address 'recipe[elixir_web::default]'


You can also chain commands, so for instance if you already have a domain purchased with the relevant A & CNAME records pointing to your instances web address, and you want to provision a postgresql database on this server as well, you could simply run:

./deploy_kitchen.sh ubuntu@your_instance_address 'recipe[elixir_web::default],recipe[elixir_web::postgresql],recipe[elixir_web::certbot],recipe[elixir_web::nginx]'

You would end up with a server with - shown by the results of each recipe:

**recipe[elixir_web::default]**
LANG, LC_ALL and LANGUAGE locales set to en_US.UTF-8

A user named whatever you want (usually `deploy`)

With a bash shell associated to it, and a home directory (e.g. `/home/deploy`)

UFW installed

EMACS installed, with a bunch of useful packages and settings

NGINX installed

SSH keys copied to this user's `authorized_keys` (customisable from where to copy them)

A `.swapon.sh` and `.swapoff.sh` bash scripts

Basic nginx available-site & enabled-site

The environment variables you need exported through `~/.profile`

A systemd service, correctly sourcing those variables as well, with restart on failure for your webapp.

In all relevant places, as well as name of the services and what not, your app name will be used.

**recipe[elixir_web::postgresql]**
Installs postgresql from postgresql apt-repository and verify it

Creates a postgres user, with a password and create a database for it (that you can customise, both user name, password and database name)

Ready to be used

**recipe[elixir_web::certbot]**
Installs certbot and requests the challenge for the domains you specify (both primary `something.com` and `www.something.com`), and generates a strong diffie-hellman key, along with the correct settings for using it (which sounds really cool but I don't totally understand)

It also sets up a cron task for renewing your certs every 60 days.

**recipe[elixir_web::nginx]**
Creates the SSL params snippet to use the strong diffie-hellman key with your certs, and updates your nginx conf to redirect traffic from http to https, and www.something.com to something.com


The best of this is that, with exception of the certbot recipe, all recipes are idempotent, meaning that there's no problem in running them multiple times, and due to the way chef works, you can basically update your templates and recipes on your local computer and immediately deploy them again and it will git diff the changes and only apply the changes were needed.

Assuming you're ok with these assumptions the only thing you need to do is fill out the `environment` file prior to deploying your recipes, for instance, this is all you need to set to provision your servers:

```
CHEFDK_V=2.5.3

ROOT_PATH=/root
DEPLOYMENT_USER=deploy
SSH_KEY_PATH=/root/.ssh/authorized_keys

CERTBOT_EMAIL=youremail@address.com

DOMAIN_MAIN=your_domain.com
DOMAIN_SECONDARY=www.your_domain.com

APP_NAME=yourapp
PORT=8888
APP_HOST=your_domain.com
APP_SCHEME=https
APP_PORT=443
APP_STATIC_HOST=something.cloudfront.net

SWAPSIZE=1024

SENDGRID_API_PROD=sendgrid_api_key
DB_USERNAME=deploy
DB_PASSWORD=the_password_you_want_for_db
DB_NAME=the_production_db_name
DB_POOLSIZE=15
REPLACE_OS_VARS=true

SECRET_KEY_BASE=a_random_generated_secret_key
```

(check the environment file to see a description and read the recipes, ruby makes it very easy to understand what's happening, it's like plain english)

You can add whatever variables to this file and they will be sourced automatically to the .profiles and be made available to the systemd task. With these you can easily set variables here and further down the line set them in your `prod.secret.exs` file, allowing you to very easily customise the config during build, and in case you use runtime definitions, they will be correctly set on the systemd environment where your app runs.

You can also turn on the swap partition by running ssh -t deploy@address sudo './.swapon.sh' or `./.swapoff.sh` to turn it off (which can be useful for building)

Because it assumes you're using phoenix, you might need to adjust your edeliver `config` file slightly, in order to build the assets, below is a usable config:

```
APP="yourapp"
ECTO_REPOSITORY="YourAppWeb.Repo"

BUILD_HOST="instance_address"
BUILD_USER="deploy"
BUILD_AT="/tmp/edeliver/$APP/builds"

RELEASE_DIR="/tmp/edeliver/$APP/builds/_build/prod/rel/$APP"

GIT_CLEAN_PATHS="_build rel priv/static"

PRODUCTION_HOSTS="instance_address"
PRODUCTION_USER="deploy"
DELIVER_TO="/home/deploy"

# For *Phoenix* projects, symlink prod.secret.exs to our tmp source
pre_erlang_get_and_update_deps() {
  local _prod_secret_path="/home/deploy/prod.secret.exs"
  if [ "$TARGET_MIX_ENV" = "prod" ]; then
    __sync_remote "
      ln -sfn '$_prod_secret_path' '$BUILD_AT/config/prod.secret.exs'
    "
  fi
}

pre_erlang_clean_compile() {
  status "Running phoenix.digest" # log output prepended with "----->"
  __sync_remote " # runs the commands on the build host
    # [ -f ~/.profile ] && source ~/.profile # load profile (optional)
    source ~/.profile
    # echo \$PATH # check if rbenv is in the path
    set -e # fail if any command fails (recommended)
    cd '$BUILD_AT' # enter the build directory on the build host (required)
    # prepare something
    mkdir -p priv/static # required by the phoenix.digest task
    echo 'Entering Assets Folder to run deploy'
    cd assets
    yarn install
    yarn run deploy
    echo 'Returning to main folder'
    cd ..
    echo 'Running phoenix.digest'
    APP='$APP' MIX_ENV='$TARGET_MIX_ENV' $MIX_CMD phx.digest $SILENCE
  "
}
```

For a viable prod.secret.exs file you can look into the templates folder. This is a template so you should clean it up accordingly (you'll also need to set your app there so the configs are correctly set...)

Next step will be adding a staging environment that can be different from the production environment, so that you can build a production like server but with specific environment values for staging - if you can run your staging with the same environment as production then all you need to do is set the edeliver config staging values and then provision your staging server just the same way you would your production one.

And after that making the certbot usage idempotent as well.

