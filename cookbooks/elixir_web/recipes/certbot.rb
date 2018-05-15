# coding: utf-8
domain_main = ENV['DOMAIN_MAIN']
domain_secondary = ENV['DOMAIN_SECONDARY']
deploy_user = ENV['DEPLOYMENT_USER']
email = ENV['CERTBOT_EMAIL']

raise "\n\n################\ndomain_main is not set in certbot recipe\n################\n" if domain_main !~ /[^[:space:]]/
raise "\n\n################\ndomain_secondary for app is not set in certbot recipe\n################\n" if domain_secondary !~ /[^[:space:]]/
aise "\n\n################\nUser for app is not set\n################\n" if deploy_user !~ /[^[:space:]]/

apt_package 'software-properties-common'

apt_repository 'certbot' do
  uri 'ppa:certbot/certbot'
end

apt_update

apt_package 'certbot'

bash 'create certbot' do
  cwd "/home/#{deploy_user}"
  code <<-EOF
  mkdir certbot
  certbot certonly --webroot --webroot-path=/home/#{deploy_user}/certbot/ -d #{domain_main} -d #{domain_secondary} -n -m #{email} --agree-tos --no-eff-email
  tar zcvf /tmp/letsencrypt_backup_$(date +”%Y-%m-%d_%H%M”).tar.gz /etc/letsencrypt
  openssl dhparam -out /etc/letsencrypt/dhparam.pem 2048
  EOF
end


file '/etc/cron.d/certbot_renewal' do
  content <<-EOF
  # run every day at at 0:30am, renew Let's Encrypt certificates over 60 days old
  30 0 * * *   certbot renew --renew-hook "service nginx reload"
  EOF
end
