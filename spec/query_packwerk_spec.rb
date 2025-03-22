# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk do
  include_context 'pseudo packs'

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
