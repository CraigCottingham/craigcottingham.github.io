# chef-solo -c /etc/chef/solo.rb -j http://craigcottingham.github.com/code/chef/solo.json
file_cache_path  "/var/chef"
cookbook_path    "/var/chef/cookbooks"
log_level        :info
log_location     STDOUT
ssl_verify_mode  :verify_none