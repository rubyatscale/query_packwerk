# typed: false
# frozen_string_literal: true

module PackHelpers
  def write_package_yml(name, enforce_privacy: true, enforce_dependencies: true, dependencies: [], owner: nil,
                        config: {})
    package_config = {
      'dependencies' => dependencies,
      'enforce_privacy' => enforce_privacy,
      'enforce_dependencies' => enforce_dependencies,
      'metadata' => { 'owner' => owner }
    }

    package_config = package_config.merge(config)
    package_config.delete('enforce_privacy') if enforce_privacy.nil?

    write_pack(name, package_config)
  end

  def write_pack_with_violations(pack_name:, violations:)
    write_package_yml(pack_name)
    write_violations(pack_name: pack_name, violations: violations)
  end

  def write_violations(pack_name:, violations:)
    expected_violation_keys = %i[class_name files to_package_name type]

    package_todo = Hash.new do |references, violated_pack_name|
      references[violated_pack_name] = Hash.new do |constants_violated, constant_name|
        constants_violated[constant_name] = Hash.new do |violation_data, key|
          violation_data[key] = []
        end
      end
    end

    violations.each do |violation|
      missing_keys = expected_violation_keys - violation.keys
      raise ArgumentError, "Missing keys: #{missing_keys}" unless missing_keys.empty?

      constant_name, files, pack_name, type = violation.slice(:class_name, :files, :to_package_name, :type).values

      package_todo[pack_name][constant_name].merge!(
        'files' => files,
        'violations' => [type]
      ) { |_k, old, current| (old + current).uniq }
    end

    write_package_todo(pack_name: pack_name, references: package_todo)
  end

  # packs/authorization:
  #   "::UserRole":
  #     violations:
  #     - privacy
  #     files:
  #     - packs/alerts/app/models/alert_confirmation.rb
  def write_package_todo(pack_name:, references:)
    references.each_value do |constants_violated|
      constants_violated.each do |constant_name, violation_info|
        relevant_keys = violation_info.transform_keys(&:to_sym).slice(:violations, :files)

        raise ArgumentError, "Must provide violations and files for each constant: #{constant_name}" unless relevant_keys.key?(:violations) && relevant_keys.key?(:files)
      end
    end

    write_file("#{pack_name}/package_todo.yml", references.to_yaml)
  end
end
