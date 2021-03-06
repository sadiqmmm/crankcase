require 'fileutils'

$phpmyadmin_version = "3.4"
$phpmyadmin_cart_root = "/usr/libexec/stickshift/cartridges/embedded/phpmyadmin-#{$phpmyadmin_version}"
$phpmyadmin_hooks = $phpmyadmin_cart_root + "/info/hooks"
$phpmyadmin_config = $phpmyadmin_hooks + "/configure"
$phpmyadmin_config_format = "#{$phpmyadmin_config} %s %s %s"
$phpmyadmin_deconfig = $phpmyadmin_hooks + "/deconfigure"
$phpmyadmin_deconfig_format = "#{$phpmyadmin_deconfig} %s %s %s"
$phpmyadmin_proc_regex = /httpd -C Include .*phpmyadmin/

Given /^a new phpmyadmin$/ do
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']
  command = $phpmyadmin_config_format % [app_name, namespace, account_name]

  outbuf = []
  exit_code = runcon command,  $selinux_user, $selinux_role, $selinux_type, outbuf

  if exit_code != 0
    raise "Error running #{command}: returned #{exit_code}"
  end
end

Given /^phpmyadmin is (running|stopped)$/ do | status |
  action = status == "running" ? "start" : "stop"

  acct_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']
  daemon_name = 'httpd'

  command = "#{$phpmyadmin_hooks}/#{action} #{app_name} #{namespace} #{acct_name}"

  num_daemons = num_procs_like acct_name, $phpmyadmin_proc_regex
  outbuf = []

  case action
  when 'start'
    if num_daemons == 0
      runcon command,  $selinux_user, $selinux_role, $selinux_type, outbuf
    end
    exit_test = lambda { |tval| tval > 0 }
  when 'stop'
    if num_daemons > 0
      runcon command,  $selinux_user, $selinux_role, $selinux_type, outbuf
    end
    exit_test = lambda { |tval| tval == 0 }
  # else
  #   raise an exception
  end

  # now loop until it's true
  max_tries = 10
  poll_rate = 3
  tries = 0
  num_daemons = num_procs_like acct_name, $phpmyadmin_proc_regex
  while (not exit_test.call(num_daemons) and tries < max_tries)
    tries += 1
    sleep poll_rate
    num_daemons = num_procs_like acct_name, $phpmyadmin_proc_regex
  end
end

When /^I configure phpmyadmin$/ do
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']
  command = $phpmyadmin_config_format % [app_name, namespace, account_name]

  outbuf = []
  exit_code = runcon command,  $selinux_user, $selinux_role, $selinux_type, outbuf

  if exit_code != 0
    raise "Error running #{command}: returned #{exit_code}"
  end
end

When /^I deconfigure phpmyadmin$/ do
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']
  command = $phpmyadmin_deconfig_format % [app_name, namespace, account_name]
  exit_code = runcon command,  $selinux_user, $selinux_role, $selinux_type
  if exit_code != 0
    raise "Command failed with exit code #{exit_code}"
  end
end

When /^I (start|stop|restart) phpmyadmin$/ do |action|
  acct_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']

  phpmyadmin_user_root = "#{$home_root}/#{acct_name}/phpmyadmin-#{$phpmyadmin_version}"

  outbuf = []
  command = "#{$phpmyadmin_hooks}/#{action} #{app_name} #{namespace} #{acct_name}"
  exit_code = runcon command,  $selinux_user, $selinux_role, $selinux_type, outbuf

  if exit_code != 0
    raise "Command failed with exit code #{exit_code}"
  end
end

Then /^a phpmyadmin http proxy file will( not)? exist$/ do | negate |
  acct_name = @account['accountname']
  app_name = @app['name']
  namespace = @app['namespace']

  conf_file_name = "#{acct_name}_#{namespace}_#{app_name}/phpmyadmin-#{$phpmyadmin_version}.conf"
  conf_file_path = "#{$libra_httpd_conf_d}/#{conf_file_name}"

  if not negate
    File.exists?(conf_file_path).should be_true
  else
    File.exists?(conf_file_path).should be_false
  end
end

Then /^a phpmyadmin httpd will( not)? be running$/ do | negate |
  acct_name = @account['accountname']
  acct_uid = @account['uid']
  app_name = @app['name']

  max_tries = 20
  poll_rate = 3
  exit_test = negate ? lambda { |tval| tval == 0 } : lambda { |tval| tval > 0 }

  tries = 0
  num_httpds = num_procs_like acct_name, $phpmyadmin_proc_regex
  while (not exit_test.call(num_httpds) and tries < max_tries)
    tries += 1
    sleep poll_rate
  end

  if not negate
    num_httpds.should be > 0
  else
    num_httpds.should be == 0
  end
end

Then /^the phpmyadmin directory will( not)? exist$/ do | negate |
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']

  phpmyadmin_user_root = "#{$home_root}/#{account_name}/phpmyadmin-#{$phpmyadmin_version}"
  begin
    phpmyadmin_dir = Dir.new phpmyadmin_user_root
  rescue Errno::ENOENT
    phpmyadmin_dir = nil
  end

  unless negate
    phpmyadmin_dir.should be_a(Dir)
  else
    phpmyadmin_dir.should be_nil
  end
end

Then /^phpmyadmin log files will( not)? exist$/ do | negate |
  acct_name = @account['accountname']
  acct_uid = @account['uid']
  app_name = @app['name']
  log_dir_path = "#{$home_root}/#{acct_name}/phpmyadmin-#{$phpmyadmin_version}/logs"
  begin
    log_dir = Dir.new log_dir_path
    status = (log_dir.count > 2)
  rescue
    status = false
  end

  if not negate
    status.should be_true
  else
    status.should be_false
  end
end

Then /^the phpmyadmin control script will( not)? exist$/ do | negate |
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']

  phpmyadmin_user_root = "#{$home_root}/#{account_name}/phpmyadmin-#{$phpmyadmin_version}"
  phpmyadmin_startup_file = "#{phpmyadmin_user_root}/#{app_name}_phpmyadmin_ctl.sh"

  begin
    startfile = File.new phpmyadmin_startup_file
  rescue Errno::ENOENT
    startfile = nil
  end

  unless negate
    startfile.should be_a(File)
  else
    startfile.should be_nil
  end
end

# Pulls the reverse proxy destination from the proxy conf file and ensures
# the path it forwards to is accessible via the external IP of the instance.
Then /^the phpmyadmin web console url will be accessible$/ do
  acct_name = @account['accountname']
  app_name = @app['name']
  namespace = @app['namespace']

  conf_file_name = "#{acct_name}_#{namespace}_#{app_name}/phpmyadmin-#{$phpmyadmin_version}.conf"
  conf_file_path = "#{$libra_httpd_conf_d}/#{conf_file_name}"

  # The URL segment for the cart lives in the proxy conf
  cart_path = `/bin/awk '/ProxyPassReverse/ {printf "%s", $2;}' #{conf_file_path}`

  # Assemble a test URL for the cart. This seems pretty cheesy. I could query the root,
  # but we'll get a 302 redirect, and I'm not sure if that's a good test.
  conf_url = "https://127.0.0.1#{cart_path}/js/sql.js"

  # Strip just the status code out of the response. Set the Host header to 
  # simulate an external request, exercising the front-end httpd proxy.
  res = `/usr/bin/curl -k -w %{http_code} -s -o /dev/null -H 'Host: #{app_name}-#{namespace}.dev.rhcloud.com' #{conf_url}`

  raise "Expected 200 response from #{conf_url}, got #{res}" unless res == "200"
end
