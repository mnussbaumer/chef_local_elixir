db_user = ENV['DB_USERNAME']
db_password = ENV['DB_PASSWORD']
db_name = ENV['DB_NAME']

raise "\n\n################\nDB Name not specified ('DB_NAME')\n################\n" if db_name !~ /[^[:space:]]/

raise "\n\n################\nDB User Role Password not specified ('DB_PASSWORD')\n################\n" if db_password !~ /[^[:space:]]/

raise "\n\n################\nDB User Role not specified ('DB_USERNAME')\n################\n" if db_user !~ /[^[:space:]]/

# some systems (i.e. scaleaway need to have this installed - in aws is not required)
apt_package 'software-properties-common'

bash 'install repository' do
  code <<-EOH
  sudo add-apt-repository "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main"
  wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
  sudo apt-get update
  EOH
end

apt_package 'postgresql'
apt_package 'postgresql-contrib'

bash 'create_db_and_users' do
  user 'postgres'
  code <<-EOH
    sudo su postgres
    psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='#{db_user}'" | grep -q 1 || psql -c "CREATE ROLE #{db_user} WITH PASSWORD '#{db_password}' CREATEDB LOGIN;"
    psql -tAc "SELECT 1 FROM pg_database WHERE datname='#{db_name}'" | grep -q 1 || psql -c "CREATE DATABASE #{db_name} OWNER #{db_user};"
  EOH
end
