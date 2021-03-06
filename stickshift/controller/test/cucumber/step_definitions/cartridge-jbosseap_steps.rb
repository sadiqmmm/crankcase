$cartridge_root ||= "/usr/libexec/stickshift/cartridges"
$jbosseap_version = "jbosseap-6.0"
$jbosseap_cartridge = "#{$cartridge_root}/#{$jbosseap_version}"
#$jbosseap_common_conf_path = "#{$jbosseap_cartridge}/info/configuration/etc/conf/httpd_nolog.conf"
$jbosseap_hooks = "#{$jbosseap_cartridge}/info/hooks"
$jbosseap_config_path = "#{$jbosseap_hooks}/configure"
# app_name namespace acct_name
$jbosseap_config_format = "#{$jbosseap_config_path} '%s' '%s' '%s'"
$jbosseap_deconfig_path = "#{$jbosseap_hooks}/deconfigure"
$jbosseap_deconfig_format = "#{$jbosseap_deconfig_path} '%s' '%s' '%s'"

$jbosseap_start_path = "#{$jbosseap_hooks}/start"
$jbosseap_start_format = "#{$jbosseap_start_path} '%s' '%s' '%s'"

$jbosseap_stop_path = "#{$jbosseap_hooks}/stop"
$jbosseap_stop_format = "#{$jbosseap_stop_path} '%s' '%s' '%s'"

$jbosseap_status_path = "#{$jbosseap_hooks}/status"
$jbosseap_status_format = "#{$jbosseap_status_path} '%s' '%s' '%s'"

When /^I configure a jbosseap application$/ do
  account_name = @account['accountname']
  namespace = @account['namespace']
  app_name = @account['appnames'][0]
  @app = {
    'name' => app_name,
    'namespace' => namespace
  }
  rhc_do('configure_jbosseap') do
    begin
      command = $jbosseap_config_format % [app_name, namespace, account_name]
      buffer = []
      exit_code = runcon(command, $selinux_user, $selinux_role, $selinux_type, buffer)
      raise "Error running #{command}: Exit code: #{exit_code}" if exit_code != 0
    rescue Exception => e
      command = $jbosseap_deconfig_format % [app_name, namespace, account_name]
      runcon(command, $selinux_user, $selinux_role, $selinux_type)
      raise
    end
  end
end

Given /^a new jbosseap application$/ do
  account_name = @account['accountname']
  app_name = @account['appnames'][0]
  namespace = @account['namespace']
  @app = {
    'namespace' => namespace,
    'name' => app_name
  }
  command = $jbosseap_config_format % [app_name, namespace, account_name]
  runcon command, $selinux_user, $selinux_role, $selinux_type
end

When /^I deconfigure the jbosseap application$/ do
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']
  command = $jbosseap_deconfig_format % [app_name, namespace, account_name]
  runcon command,  $selinux_user, $selinux_role, $selinux_type
end

When /^I (start|stop|restart) the jbosseap service$/ do |action|
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']

  @app['pid'] = 0 if action == "restart"

  command = "#{$jbosseap_hooks}/%s %s %s %s" % [action, app_name, namespace, account_name]
  exit_status = runcon command, $selinux_user, $selinux_role, $selinux_type
  if exit_status != 0
    raise "Unable to %s for %s %s %s" % [action, app_name, namespace, account_name]
  end
  sleep 5

  if action == "restart"
    # new_pid = ??
    # @app['pid'].should not_be(new_pid)
  end
end

Then /^the jbosseap daemon pid will be different$/ do
  pending
end

Given /^the jbosseap service is (running|stopped)$/ do |start_state|
  account_name = @account['accountname']
  namespace = @app['namespace']
  app_name = @app['name']

  case start_state
  when 'running':
      fix_action = 'start'
      good_exit = 0
  when 'stopped':
      fix_action = 'stop'
      good_exit = 0
  end

  # check
  status_command = $jbosseap_status_format %  [app_name, namespace, account_name]
  exit_status = runcon status_command, $selinux_user, $selinux_role, $selinux_type

  if exit_status != good_exit
    # fix it
    fix_command = "#{$jbosseap_hooks}/%s %s %s %s" % [fix_action, app_name, namespace, account_name]
    exit_status = runcon fix_command, $selinux_user, $selinux_role, $selinux_type
    if exit_status != 0
      raise "Unable to %s for %s %s %s" % [fix_action, app_name, namespace, account_name]
    end
    sleep 5
    
    # check exit status
    exit_status = runcon status_command, $selinux_user, $selinux_role, $selinux_type
    if exit_status != good_exit
      raise "Received bad status (%d) after %s for %s %s %s" % [exit_status, fix_action, app_name, namespace, account_name]
    end
  end
end

Then /^a jbosseap application directory will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_dir = "#{$home_root}/#{acct_name}/jbosseap-6.0"
  status = (File.exists? cart_instance_dir and File.directory? cart_instance_dir) 
  # TODO - need to check permissions and SELinux labels

  if not negate
    status.should be_true "#{cart_instance_dir} does not exist or is not a directory"
  else
    status.should be_false "file #{cart_instance_dir} exists and is a directory.  it should not"
  end
end

Then /^the jbosseap application directory tree will( not)? be populated$/ do |negate|
  # This directory should contain specfic elements:
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_root = "#{$home_root}/#{acct_name}/jbosseap-6.0"

  file_list =  ['repo', 'run', 'tmp', 'data', $jbosseap_version, 
                "#{$jbosseap_version}/bin",  
                "#{$jbosseap_version}/standalone/configuration"
               ]

  file_list.each do |file_name| 
    file_path = cart_instance_root + "/" + file_name
    file_exists = File.exists? file_path
    unless negate
      file_exists.should be_true "file #{file_path} does not exist"
    else
      file_exists.should be_false "file #{file_path} exists, and should not"
    end
  end
end

Then /^the jbosseap server and module files will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_dir = "#{$home_root}/#{acct_name}/jbosseap-6.0"
  jboss_root = cart_instance_dir + "/" + $jbosseap_version

  file_list = [ "#{jboss_root}/jboss-modules.jar", "#{jboss_root}/modules" ]

  file_list.each do |file_name|
    file_exists = File.exists? file_name
    unless negate
      file_exists.should be_true "file #{file_name} should exist and does not"
      file_link = File.symlink? file_name
      file_link.should be_true "file #{file_name} should be a symlink and is not"
    else
      file_exists.should be_false "file #{file_name} should not exist and does"
    end
  end
end

Then /^the jbosseap server configuration files will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_dir = "#{$home_root}/#{acct_name}/jbosseap-6.0"
  jboss_root = cart_instance_dir + "/" + $jbosseap_version
  jboss_conf_dir = jboss_root + "/standalone/configuration"
  file_list = ["#{jboss_conf_dir}/standalone.xml", 
               "#{jboss_conf_dir}/logging.properties"
             ]

  file_list.each do |file_name|
    file_exists = File.exists? file_name
    unless negate
      file_exists.should be_true "file #{file_name} should exist and does not"
    else
      file_exists.should be_false "file #{file_name} should not exist and does"
    end
  end
end

Then /^the jbosseap standalone scripts will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_dir = "#{$home_root}/#{acct_name}/jbosseap-6.0"
  jboss_root = cart_instance_dir + "/" + $jbosseap_version
  jboss_bin_dir = jboss_root + "/bin"
  file_name = "#{jboss_bin_dir}/standalone.sh"
  file_exists = File.exists? file_name
  unless negate
    file_exists.should be_true "file #{file_name} should exist and does not"
  else
    file_exists.should be_false "file #{file_name} should not exist and does"
  end
end

Then /^a jbosseap git repo will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  git_root = "#{$home_root}/#{acct_name}/git/#{app_name}.git"
  file_exists = File.exists? git_root
  unless negate
    file_exists.should be_true "directory #{git_root} should exist and does not"
  else
    file_exists.should be_false "directory #{git_root} should not exist and does"
  end
end

Then /^the jbosseap git hooks will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  git_root = "#{$home_root}/#{acct_name}/git/#{app_name}.git"
  git_hook_dir = git_root + "/" + "hooks"
  hook_list = ["pre-receive", "post-receive"]

  hook_list.each do |file_name|
    file_path = "#{git_hook_dir}/#{file_name}"
    file_exists = File.exists? file_path
    unless negate
      file_exists.should be_true "file #{file_path} should exist and does not"
      file_exec = File.executable? file_path
      file_exec.should be_true "file #{file_path} should be executable and is not"
    else
      file_exists.should be_false "file #{file_path} should not exist and does"
    end
  end
end

Then /^a jbosseap deployments directory will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  app_root = "#{$home_root}/#{acct_name}/app-root"
  deploy_root = Dir.new "#{app_root}/repo/deployments"
  
  deploy_contents = ['ROOT.war']

  deploy_contents.each do |file_name|
    unless negate
      deploy_root.member?(file_name).should be_true "file #{deploy_root.path}/#{file_name} should exist and does not"
    else
      deploy_root.member?(file_name).should be_false "file #{deploy_root.path}/#{file_name} should not exist and does"
    end
  end
end

Then /^the jbosseap maven repository will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  m2_root = "#{$home_root}/#{acct_name}/.m2"
  m2_repo_path = "#{m2_root}/repository"
  m2_repo_list = ["classworlds", "com", "commons-cli", "junit", "org", "xpp3"]

  m2_repo_list.each do |file_name|
    file_path = "#{m2_repo_path}/#{file_name}"
    file_exists = File.exists? file_path
    unless negate
      file_exists.should be_true "file #{file_path} should exist and does not"
      file_dir = File.directory? file_path
      file_dir.should be_true "file #{file_path} should be a directory and is not"
    else
      file_exists.should be_false "file #{file_path} should not exist and does"
    end
  end
end

Then /^the openshift environment variable files will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  env_root = "#{$home_root}/#{acct_name}/.env"
  env_list = ["OPENSHIFT_GEAR_DIR", 
              "OPENSHIFT_REPO_DIR", 
              "OPENSHIFT_INTERNAL_IP",
              "OPENSHIFT_INTERNAL_PORT",
              "OPENSHIFT_LOG_DIR",
              "OPENSHIFT_DATA_DIR",
              "OPENSHIFT_TMP_DIR",
              "OPENSHIFT_RUN_DIR",
              "OPENSHIFT_GEAR_NAME",
              "OPENSHIFT_GEAR_CTL_SCRIPT"
              ]

  env_list.each do |file_name|
    file_path = "#{env_root}/#{file_name}"
    file_exists = File.exists? file_path
    unless negate
      file_exists.should be_true "file #{file_path} should exist and does not"
    else
      file_exists.should be_false "file #{file_path} should not exist and does"
    end
  end

end

Then /^a jbosseap service startup script will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  cart_instance_dir = "#{$home_root}/#{acct_name}/jbosseap-6.0"
  app_ctrl_script = "#{cart_instance_dir}/#{app_name}_ctl.sh"

  file_exists = File.exists? app_ctrl_script
  unless negate
    file_exists.should be_true "file #{app_ctrl_script} should exist and does not"
    File.executable?(app_ctrl_script).should be_true "file #{app_ctrl_script} should be executable and is not"
  else
    file_exists.should be_false "file #{file_name} should not exist and does"
  end
end

Then /^a jbosseap source tree will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  app_root = "#{$home_root}/#{acct_name}/app-root"
  repo_root_path = "#{app_root}/repo"

  unless negate
    File.exists?(repo_root_path).should be_true "file #{repo_root_path} should exist and does not"
    File.directory?(repo_root_path).should be_true "file #{repo_root_path} should be a directory and is not"
    src_root = Dir.new repo_root_path
    src_contents = ['deployments', 'pom.xml', 'README', 'src', ".gitignore"]

    src_contents.each do |file_name|
      src_root.member?(file_name).should be_true "file #{app_root}/repo/#{file_name} should exist and does not"
    end
  else
    File.exists?(repo_root_path).should be_false "file #{repo_root_path} should not exist and does"
  end
  
end

Then /^a jbosseap application http proxy file will( not)? exist$/ do | negate |
  acct_name = @account['accountname']
  app_name = @app['name']
  namespace = @app['namespace']

  conf_file_name = "#{acct_name}_#{namespace}_#{app_name}.conf"
  conf_file_path = "#{$libra_httpd_conf_d}/#{conf_file_name}"

  unless negate
    File.exists?(conf_file_path).should be_true
  else
    File.exists?(conf_file_path).should be_false
  end
end

Then /^a jbosseap application http proxy directory will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']
  namespace = @app['namespace']

  conf_dir_path = "#{$libra_httpd_conf_d}/#{acct_name}_#{namespace}_#{app_name}"

  status = (File.exists? conf_dir_path and File.directory? conf_dir_path)
  # TODO - need to check permissions and SELinux labels

  if not negate
    status.should be_true "#{conf_dir_path} does not exist or is not a directory"
  else
    status.should be_false "file #{conf_dir_path} exists and is a directory.  it should not"
  end
end

Then /^a jbosseap daemon will( not)? be running$/ do |negate|
  acct_name = @account['accountname']
  acct_uid = @account['uid']
  app_name = @app['name']

  max_tries = 7
  poll_rate = 3
  exit_test = negate ? lambda { |tval| tval == 0 } : lambda { |tval| tval > 0 }
  
  tries = 0
  num_javas = num_procs acct_name, 'java'
  while (not exit_test.call(num_javas) and tries < max_tries)
    tries += 1
    sleep poll_rate
    found = exit_test.call num_javas
  end

  if not negate
    num_javas.should be > 0
  else
    num_javas.should be == 0
  end
end

Then /^the jbosseap daemon log files will( not)? exist$/ do |negate|
  acct_name = @account['accountname']
  app_name = @app['name']

  log_dir = "#{$home_root}/#{acct_name}/#{app_name}/logs"
  log_list = ["boot.log", "server.log"]

  log_list.each do |file_name|
    file_path = "#{log_dir}/#{file_name}"
    file_exists = File.exists? file_path
    unless negate
      file_exists.should be_true "file #{file_path} should exist and does not"
    else
      file_exists.should be_false "file #{file_path} should not exist and does"
    end
  end
end
