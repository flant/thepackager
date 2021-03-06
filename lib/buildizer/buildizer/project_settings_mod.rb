module Buildizer
  class Buildizer
    module ProjectSettingsMod
      def project_settings_path
        package_path.join('.buildizer.yml')
      end

      def project_settings
        @project_settings ||= begin
          project_settings_path.load_yaml.tap do |settings|
            settings['master'] = options[:master] if options.key? :master
          end
        end
      end

      def project_settings_save!
        write_yaml project_settings_path, project_settings
      end

      def project_settings_setup!
        project_settings_save!
      end
    end # ProjectSettingsMod
  end # Buildizer
end # Buildizer
