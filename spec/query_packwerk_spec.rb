# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk do
  include_context 'pseudo packs'

  describe '#package' do
    it 'gets a package by name' do
      expect(described_class.package(package_name)).to be_a(QueryPackwerk::Package)
    end

    it 'gets a package by its name in packs/, as violations_for does' do
      expect(described_class.package('honey_production')&.name).to eq('packs/honey_production')
    end

    it 'returns nil if the package does not exist' do
      expect(described_class.package('not_here')).to be_nil
    end
  end

  describe '#violations_for' do
    it 'gets all violations for a pack' do
      violations = described_class.violations_for(package_name)

      expect(violations).to be_a(QueryPackwerk::Violations)
      expect(violations.count).not_to eq(0)
    end

    it 'gets nothing for an empty pack' do
      violations = described_class.violations_for('not_here_boss')
      expect(violations.count).to eq(0)
    end
  end

  describe '#violation_sources_for' do
    it 'gets violation sources grouped by class name' do
      expect(described_class.violation_sources_for(package_name)).to eq(
        {
          '::Backfills::BackfillPollinationCoveredPeriodDates' => [
            [
              'db/data/20210309211702_backfill_pollination_covered_period_dates.rb:3', 'Backfills::BackfillPollinationCoveredPeriodDates.run!'
            ]
          ],
          '::Mutations::HoneyProduction::SaveNectar' => [
            [
              'packs/hivemind_subgraph/app/lib/objects/mutation.rb:1',
              'Mutations::HoneyProduction::SaveNectar'
            ]
          ],
          '::HoneyProductionNectar' => [
            [
              'packs/hive_graphql_concerns/app/public/objects/apiary.rb:3',
              '::HoneyProductionNectar.as_of_now.find_by(apiary_id: object.id)'
            ]
          ],
          '::HoneyProductionNectarPollinationInfo' => [
            [
              'packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb:6',
              "HoneyProductionNectarPollinationInfo.\n    where(apiary_id: @apiary.id).\n    where.not(nectar_amount: nil).\n    exists?"
            ],
            [
              'packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb:6',
              "HoneyProductionNectarPollinationInfo.\n    where(apiary_id: @apiary.id).\n    where.not(nectar_amount: nil).\n    exists?"
            ]
          ],
          '::Beekeeping::HoneyProduction::Nectars' => [
            [
              'packs/hive_graphql_concerns/app/public/objects/apiary.rb:7',
              '::Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: object.id)'
            ]
          ]
        }
      )
    end
  end

  describe '#violation_counts_for' do
    it 'gets violation counts grouped by class name' do
      expect(described_class.violation_counts_for(package_name)).to eq(
        {
          '::Backfills::BackfillPollinationCoveredPeriodDates' => {
            'Backfills::BackfillPollinationCoveredPeriodDates.run!' => 1
          },
          '::Mutations::HoneyProduction::SaveNectar' => {
            'Mutations::HoneyProduction::SaveNectar' => 1
          },
          '::HoneyProductionNectar' => {
            '::HoneyProductionNectar.as_of_now.find_by(apiary_id: object.id)' => 1
          },
          '::HoneyProductionNectarPollinationInfo' => {
            "HoneyProductionNectarPollinationInfo.\n    where(apiary_id: @apiary.id).\n    where.not(nectar_amount: nil).\n    exists?" => 2
          },
          '::Beekeeping::HoneyProduction::Nectars' => {
            '::Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: object.id)' => 1
          }
        }
      )
    end
  end

  describe '#anonymous_violation_sources_for' do
    it 'gets violation sources grouped by class name' do
      expect(described_class.anonymous_violation_sources_for(package_name)).to eq(
        '::Backfills::BackfillPollinationCoveredPeriodDates' => [
          'Backfills::BackfillPollinationCoveredPeriodDates.run!'
        ],
        '::Mutations::HoneyProduction::SaveNectar' => [
          'Mutations::HoneyProduction::SaveNectar'
        ],
        '::HoneyProductionNectar' => [
          'HoneyProductionNectar.as_of_now.find_by(apiary_id: _)'
        ],
        '::HoneyProductionNectarPollinationInfo' => [
          'HoneyProductionNectarPollinationInfo.where(apiary_id: _).where.not(nectar_amount: _).exists?'
        ],
        '::Beekeeping::HoneyProduction::Nectars' => [
          'Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: _)'
        ]
      )
    end
  end

  describe '#anonymous_violation_counts_for' do
    it 'gets violation sources grouped by class name' do
      expect(described_class.anonymous_violation_counts_for(package_name)).to eq(
        {
          '::Backfills::BackfillPollinationCoveredPeriodDates' => {
            'Backfills::BackfillPollinationCoveredPeriodDates.run!' => 1
          },
          '::Mutations::HoneyProduction::SaveNectar' => {
            'Mutations::HoneyProduction::SaveNectar' => 1
          },
          '::HoneyProductionNectar' => {
            'HoneyProductionNectar.as_of_now.find_by(apiary_id: _)' => 1
          },
          '::HoneyProductionNectarPollinationInfo' => {
            'HoneyProductionNectarPollinationInfo.where(apiary_id: _).where.not(nectar_amount: _).exists?' => 2
          },
          '::Beekeeping::HoneyProduction::Nectars' => {
            'Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: _)' => 1
          }
        }
      )
    end

    it 'can be given a threshold' do
      expect(described_class.anonymous_violation_counts_for(package_name, threshold: 3)).to eq({})
    end
  end
end

RSpec.describe QueryPackwerk do
  include_context 'listed references'

  describe '#references_for' do
    it "gets all references from other packs to a pack's constants" do
      references = described_class.references_for('honey_production')

      expect(references).to be_a(QueryPackwerk::References)
      expect(references.count).to eq(8)
    end
  end

  describe '#references_from' do
    it "gets all references from a pack to other packs' constants" do
      expect(described_class.references_from('hive_dashboard').map(&:constant_name).tally).to eq(
        '::HoneyProductionNectar' => 3,
        '::Beekeeping::NectarSource' => 1,
        '::Beekeeping::Nectars' => 1,
        '::ApiaryReportCard' => 1
      )
    end

    it 'takes the name of a pack outside packs/, as the root pack' do
      expect(described_class.references_from('.').map(&:location)).to eq(['app/services/apiary_summary.rb:2'])
    end
  end

  describe '#reload!' do
    it 'runs pks again for the next query' do
      described_class.references_for('honey_production')
      described_class.reload!
      described_class.references_for('honey_production')

      expect(QueryPackwerk::Pks).to have_received(:list_references).twice
    end

    it 'returns nil, which the console shows plainly, as do the reload! of each collection' do
      expect(described_class.reload!).to be_nil
      expect([QueryPackwerk::Packages, QueryPackwerk::Violations, QueryPackwerk::References].map(&:reload!)).to eq([nil, nil, nil])
    end

    it 'reads the package_todo.yml files again' do
      expect(described_class.todos_for('apiary_reports').count).to eq(1)

      write_package_todo(pack_name: 'packs/apiary_reports', references: {})
      described_class.reload!

      expect(described_class.todos_for('apiary_reports').count).to eq(0)
    end

    it 'finds a pack added since, which pks lists references from' do
      described_class.references_for('honey_production')

      write_package_yml('packs/wax_reports')
      write_file('packs/wax_reports/app/services/wax_report.rb', <<~RUBY)
        class WaxReport
          def nectar_count = HoneyProductionNectar.count
        end
      RUBY
      listed_references << {
        'file' => 'packs/wax_reports/app/services/wax_report.rb', 'line' => 2, 'column' => 21,
        'constant_name' => '::HoneyProductionNectar',
        'referencing_pack_name' => 'packs/wax_reports', 'defining_pack_name' => 'packs/honey_production',
        'violations' => [
          { 'violation_type' => 'dependency', 'strict' => false, 'recorded' => false },
          { 'violation_type' => 'privacy', 'strict' => false, 'recorded' => false }
        ]
      }
      described_class.reload!

      expect(described_class.references_for('honey_production').consumers).to include('packs/wax_reports' => 1)
    end
  end
end
