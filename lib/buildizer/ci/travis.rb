module Buildizer
  module Ci
    class Travis < Base
      class << self
        def ci_name
          'travis'
        end

        def env_vars(prefix:, **kwargs)
          kwargs.each do |name, var_name|
            define_method("#{prefix}_#{name}_var") {repo.env_vars[var_name]}
            define_method("#{prefix}_#{name}_var_name") {var_name}
            define_method("#{prefix}_#{name}_var_delete!") do
              var = send("#{prefix}_#{name}_var")
              var.delete if var
            end
            define_method("#{prefix}_#{name}_var_update!") do |value, **kwargs|
              if value
                repo.env_vars.upsert(var_name, value, **kwargs)
              else
                send("#{prefix}_#{name}_var_delete!")
              end
            end
          end # each
        end
      end # << self

      autoload :PackageCloudMod, 'buildizer/ci/travis/package_cloud_mod'
      autoload :DockerCacheMod, 'buildizer/ci/travis/docker_cache_mod'
      autoload :PackageVersionTagMod, 'buildizer/ci/travis/package_version_tag_mod'

      include PackageCloudMod
      include DockerCacheMod
      include PackageVersionTagMod

      def setup!
        buildizer.write_yaml conf_path, actual_conf
        require_tag_setup!
      end

      def configuration_actual?
        conf == actual_conf
      end

      def actual_conf
        install = [
          'sudo apt-get update',
          'sudo apt-get install -y apt-transport-https ca-certificates',
          'sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D',
          'echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" | sudo tee /etc/apt/sources.list.d/docker.list',
          'sudo apt-get update',

          # FIXME [https://github.com/docker/docker/issues/20316]:
          'sudo apt-get -o dpkg::options::="--force-confnew" install -y --force-yes docker-engine=1.9.1-0~trusty',

          'echo "docker-engine hold" | sudo dpkg --set-selections',
        ]
        install.push(*Array(buildizer_install_instructions(master: buildizer.project_settings['master'])))

        if buildizer.project_settings['master']
          buildizer_bin = 'bundle exec buildizer'
        else
          buildizer_bin = 'buildizer'
        end

        env = buildizer.builder.target_names.map {|t| "BUILDIZER_TARGET=#{t}"}

        conf.merge!(
          'dist' => 'trusty',
          'sudo' => 'required',
          'cache' => 'apt',
          'language' => 'ruby',
          'rvm' => '2.2.1',
          'install' => install,
          'before_script' => "#{buildizer_bin} prepare",
          'script' => "#{buildizer_bin} build && #{buildizer_bin} test",
          'env' => env,
          'after_success' => "#{buildizer_bin} deploy",
        )
      end

      def _git_tag
        ENV['TRAVIS_TAG']
      end

      def repo_name
        if buildizer.git_remote_url.start_with? 'http'
          buildizer.git_remote_url.split('github.com/')[1]
        else
          buildizer.git_remote_url.split(':')[1].split('.')[0]
        end
      rescue
        raise Error, error: :input_error,
                     message: "unable to determine travis repo name " +
                              "from git remote url #{buildizer.git_remote_url}"
      end

      def repo
        ::Travis::Repository.find(repo_name)
      end

      def login
        @logged_in ||= begin
          buildizer.with_log(desc: "Login into travis") do |&fin|
            buildizer.user_settings['travis'] ||= {}

            if buildizer.options[:reset_github_token]
              buildizer.user_settings['travis'].delete('github_token')
              buildizer.user_settings_save!
            end

            buildizer.user_settings['travis']['github_token'] ||= begin
              reset_github_token = true
              buildizer.secure_option(:github_token, ask: "GitHub travis access token:").to_s
            end

            ::Travis.github_auth(buildizer.user_settings['travis']['github_token'])
            buildizer.user_settings_save! if reset_github_token

            fin.call "LOGGED IN: #{::Travis::User.current.name}"
          end # with_log

          true
        end
      end

      def with_travis(&blk)
        login
        yield
      rescue ::Travis::Client::Error => err
        raise Error, message: "travis: #{err.message}"
      end
    end # Travis
  end # Ci
end # Buildizer
