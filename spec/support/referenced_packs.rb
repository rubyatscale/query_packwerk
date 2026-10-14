# typed: false
# frozen_string_literal: true

# An app whose packs reference each other's constants in each way that pks
# lists: allowed or not, recorded in a package_todo.yml or not, by a relative
# name, through an association, in ERB, after multibyte characters, and to a
# pack without an owner.
RSpec.shared_context 'referenced packs' do
  # QueryPackwerk keeps the packs it finds, so it'd keep these from, or for,
  # specs that write other packs
  around do |example|
    QueryPackwerk.reload!
    example.run
  ensure
    QueryPackwerk.reload!
  end

  before do
    write_file('packwerk.yml', "cache: false\n")
    write_package_yml('.', enforce_privacy: false, enforce_dependencies: false)
    write_package_yml('packs/honey_production', config: { 'owner' => 'Honey' })
    write_package_yml('packs/hive_dashboard', dependencies: ['packs/honey_production'])
    write_package_yml('packs/apiary_reports')

    write_package_todo(
      pack_name: 'packs/hive_dashboard',
      references: {
        'packs/honey_production' => {
          '::HoneyProductionNectar' => {
            'violations' => ['privacy'],
            'files' => [
              'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb',
              'packs/hive_dashboard/app/views/apiaries/show.html.erb'
            ]
          }
        }
      }
    )
    write_package_todo(
      pack_name: 'packs/apiary_reports',
      references: {
        'packs/honey_production' => {
          '::HoneyProductionNectar' => {
            'violations' => ['dependency'],
            'files' => ['packs/apiary_reports/app/services/apiary_report.rb']
          }
        }
      }
    )

    app_files.each { |file_name, source| write_file(file_name, source) }
  end

  let(:app_files) do
    {
      'packs/honey_production/app/models/honey_production_nectar.rb' => <<~RUBY,
        class HoneyProductionNectar < ApplicationRecord
        end
      RUBY
      'packs/honey_production/app/models/beekeeping/nectar_source.rb' => <<~RUBY,
        module Beekeeping
          class NectarSource < ApplicationRecord
          end
        end
      RUBY
      'packs/honey_production/app/public/beekeeping/nectars.rb' => <<~RUBY,
        module Beekeeping
          module Nectars
            def self.status_for(apiary_id:); end
          end
        end
      RUBY
      'packs/hive_dashboard/app/services/beekeeping/apiary_status.rb' => <<~RUBY,
        module Beekeeping
          class ApiaryStatus
            def nectar
              ::HoneyProductionNectar.as_of_now.find_by(apiary_id: 1)
            end

            def sources
              NectarSource.where(apiary_id: 1).pluck(:name)
            end

            def status
              Nectars.status_for(apiary_id: 1)
            end
          end
        end
      RUBY
      'packs/hive_dashboard/app/models/hive.rb' => <<~RUBY,
        class Hive < ApplicationRecord
          has_many :honey_production_nectars, dependent: :destroy
        end
      RUBY
      'packs/hive_dashboard/app/services/report_link.rb' => <<~RUBY,
        class ReportLink
          def card = ApiaryReportCard.new
        end
      RUBY
      'packs/hive_dashboard/app/views/apiaries/show.html.erb' => <<~ERB,
        <% if HoneyProductionNectar.as_of_now.exists?(apiary_id: @apiary.id) %>
          <p><%= HoneyProductionNectar.as_of_now.find_by(apiary_id: @apiary.id).volume %></p>
        <% end %>
      ERB
      'packs/apiary_reports/app/services/apiary_report.rb' => <<~'RUBY',
        class ApiaryReport
          def nectar_count = HoneyProductionNectar.count

          def title = "Récolte 🍯 #{HoneyProductionNectar.model_name.human}"
        end
      RUBY
      'packs/apiary_reports/app/public/apiary_report_card.rb' => <<~RUBY,
        class ApiaryReportCard
        end
      RUBY
      'app/services/apiary_summary.rb' => <<~RUBY
        class ApiarySummary
          def status = Beekeeping::Nectars.status_for(apiary_id: 1)
        end
      RUBY
    }
  end

  # What `pks list-references` prints for the app. spec/query_packwerk/pks_spec.rb
  # checks this against pks itself, when it's installed.
  let(:listed_references) do
    JSON.parse(<<~JSON).fetch('references')
      {
        "references": [
          {"file": "app/services/apiary_summary.rb", "line": 2, "column": 15, "constant_name": "::Beekeeping::Nectars", "referencing_pack_name": ".", "defining_pack_name": "packs/honey_production", "violations": []},
          {"file": "packs/apiary_reports/app/services/apiary_report.rb", "line": 2, "column": 21, "constant_name": "::HoneyProductionNectar", "referencing_pack_name": "packs/apiary_reports", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "dependency", "strict": false, "recorded": true}, {"violation_type": "privacy", "strict": false, "recorded": false}]},
          {"file": "packs/apiary_reports/app/services/apiary_report.rb", "line": 4, "column": 31, "constant_name": "::HoneyProductionNectar", "referencing_pack_name": "packs/apiary_reports", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "dependency", "strict": false, "recorded": true}, {"violation_type": "privacy", "strict": false, "recorded": false}]},
          {"file": "packs/hive_dashboard/app/models/hive.rb", "line": 2, "column": 2, "constant_name": "::HoneyProductionNectar", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "privacy", "strict": false, "recorded": false}]},
          {"file": "packs/hive_dashboard/app/services/beekeeping/apiary_status.rb", "line": 4, "column": 6, "constant_name": "::HoneyProductionNectar", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "privacy", "strict": false, "recorded": true}]},
          {"file": "packs/hive_dashboard/app/services/beekeeping/apiary_status.rb", "line": 8, "column": 6, "constant_name": "::Beekeeping::NectarSource", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "privacy", "strict": false, "recorded": false}]},
          {"file": "packs/hive_dashboard/app/services/beekeeping/apiary_status.rb", "line": 12, "column": 6, "constant_name": "::Beekeeping::Nectars", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/honey_production", "violations": []},
          {"file": "packs/hive_dashboard/app/services/report_link.rb", "line": 2, "column": 13, "constant_name": "::ApiaryReportCard", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/apiary_reports", "violations": [{"violation_type": "dependency", "strict": false, "recorded": false}]},
          {"file": "packs/hive_dashboard/app/views/apiaries/show.html.erb", "line": null, "column": null, "constant_name": "::HoneyProductionNectar", "referencing_pack_name": "packs/hive_dashboard", "defining_pack_name": "packs/honey_production", "violations": [{"violation_type": "privacy", "strict": false, "recorded": true}]}
        ]
      }
    JSON
  end
end

# Stands in for pks, with what it lists for the referenced packs
RSpec.shared_context 'listed references' do
  include_context 'referenced packs'

  before do
    allow(QueryPackwerk::Pks).to receive(:list_references).and_return(listed_references)
  end
end
