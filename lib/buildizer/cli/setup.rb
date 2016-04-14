module Buildizer
  module Cli
    class Setup < Base
      include OptionMod
      include HelperMod

      desc "all", "Setup buildizer"
      shared_options
      def all
        packager = self.class.construct_packager(options)

        if ask_setup_conf_file? packager.options_path
          version = ask("Buildizer version to use in #{packager.ci.ci_name}",
                         limited_to: ["0.0.7", "latest"],
                         default: "latest")
          packager.option_set('latest', version == 'latest')
          packager.options_setup!
        end

        if ask_setup_conf_file? packager.buildizer_conf_path
          default_build_type = packager.buildizer_conf['build_type']
          build_type = ask("build_type",
                            limited_to: ["patch", "native", "fpm"],
                            default: default_build_type)
          packager.buildizer_conf_update('build_type' => build_type)
          packager.buildizer_conf_setup!
        end

        packager.ci.setup! if packager.ci.cli.ask_setup?

        packager.overcommit_setup!
        packager.overcommit_verify_setup!
        packager.overcommit_ci_setup!
      end
    end # Setup
  end # Cli
end # Buildizer