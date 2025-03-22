# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::Violations do
  include_context 'pseudo packs'

  describe '#where' do
    it 'can query violations' do
      violation_counts = described_class.where(privacy: true).map(&:type).tally

      expect(violation_counts).to eq({ 'privacy' => 5 })
    end

    it 'can use the `===` interface for things like regex matching a field' do
      violations = described_class.where(constant_name: /::Beekeeping/).map(&:class_name)

      expect(violations).to eq(['::Beekeeping::HoneyProduction::Nectars'])
    end
  end

  describe '#anonymous_sources_with_locations' do
    it 'can get anonymized sources with their file locations' do
      # { constant => { violating code shape => [where it happened] } }
      expect(described_class.all.anonymous_sources_with_locations).to eq(
        {
          '::Backfills::BackfillPollinationCoveredPeriodDates' => {
            'Backfills::BackfillPollinationCoveredPeriodDates.run!' => [
              'db/data/20210309211702_backfill_pollination_covered_period_dates.rb:3'
            ]
          },
          '::Mutations::HoneyProduction::SaveNectar' => {
            'Mutations::HoneyProduction::SaveNectar' => [
              'packs/hivemind_subgraph/app/lib/objects/mutation.rb:1'
            ]
          },
          '::HoneyProductionNectar' => {
            'HoneyProductionNectar.as_of_now.find_by(apiary_id: _)' => [
              'packs/hive_graphql_concerns/app/public/objects/apiary.rb:3'
            ]
          },
          '::HoneyProductionNectarPollinationInfo' => {
            'HoneyProductionNectarPollinationInfo.where(apiary_id: _).where.not(nectar_amount: _).exists?' => [
              # Privacy _and_ dependency violations both apply to the same line. This is intentional
              'packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb:6',
              'packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb:6'
            ]
          },
          '::Beekeeping::HoneyProduction::Nectars' => {
            'Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: _)' => [
              'packs/hive_graphql_concerns/app/public/objects/apiary.rb:7'
            ]
          }
        }
      )
    end
  end
end
