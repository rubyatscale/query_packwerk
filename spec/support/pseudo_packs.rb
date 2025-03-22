# typed: false
# frozen_string_literal: true

RSpec.shared_context 'pseudo packs' do
  before do
    write_pack_with_violations(pack_name: package_name, violations: raw_violations)
    violating_files.each do |file_name, file_contents|
      write_file(file_name, file_contents)
    end
  end

  let(:raw_violations) do
    [
      {
        class_name: '::Mutations::HoneyProduction::SaveNectar',
        files: ['packs/hivemind_subgraph/app/lib/objects/mutation.rb'],
        to_package_name: 'packs/honey_production',
        type: 'privacy'
      }, {
        class_name: '::HoneyProductionNectar',
        files: ['packs/hive_graphql_concerns/app/public/objects/apiary.rb'],
        to_package_name: 'packs/honey_production',
        type: 'privacy'
      }, {
        class_name: '::Beekeeping::HoneyProduction::Nectars',
        files: ['packs/hive_graphql_concerns/app/public/objects/apiary.rb'],
        to_package_name: 'packs/honey_production',
        type: 'privacy'
      }, {
        class_name: '::HoneyProductionNectarPollinationInfo',
        files: ['packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb'],
        to_package_name: 'packs/honey_production',
        type: 'dependency'
      }, {
        class_name: '::HoneyProductionNectarPollinationInfo',
        files: ['packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb'],
        to_package_name: 'packs/honey_production',
        type: 'privacy'
      }, {
        class_name: '::Backfills::BackfillPollinationCoveredPeriodDates',
        files: ['db/data/20210309211702_backfill_pollination_covered_period_dates.rb'],
        to_package_name: 'packs/honey_production',
        type: 'privacy'
      }
    ]
  end

  let(:violating_files) do
    cache = {}

    cache['packs/hivemind_subgraph/app/lib/objects/mutation.rb'] = <<~RUBY
      field :save_honey_production_nectar, mutation: Mutations::HoneyProduction::SaveNectar
    RUBY

    cache['packs/hive_graphql_concerns/app/public/objects/apiary.rb'] = <<~RUBY
      def honey_production_nectar
        # TODO: Update this to use Beekeeping::HoneyProduction::Nectars.nectar_status_for
        ::HoneyProductionNectar.as_of_now.find_by(apiary_id: object.id)
      end

      def has_processed_honey_production_nectar
        nectar_status = ::Beekeeping::HoneyProduction::Nectars.nectar_status_for(apiary_id: object.id)

        return false if !nectar_status.entered_hpn_nectar_information

        nectar_status.nectar.processed
      end
    RUBY

    cache['packs/beehive_health_metrics/app/controllers/worker_bee_efficiency_controller.rb'] = <<~RUBY
      def claimed_hpn
        # Apiary reported receiving HPN nectar in most recent hive survey
        has_responded_to_survey_and_received_nectar = Hive::Survey.joins(:hive_questions).
          where('apiary_id' => @apiary.id).order(created_at: :desc).pick('hive_questions.key') == 'approved'

        entered_non_zero_nectar_amount = HoneyProductionNectarPollinationInfo.
          where(apiary_id: @apiary.id).
          where.not(nectar_amount: nil).
          exists?

        has_responded_to_survey_and_received_nectar || entered_non_zero_nectar_amount
      end
    RUBY

    cache['db/data/20210309211702_backfill_pollination_covered_period_dates.rb'] = <<~RUBY
      class BackfillPollinationCoveredPeriodDates < ActiveRecord::Migration[6.0]
        def up
          Backfills::BackfillPollinationCoveredPeriodDates.run!
        end

        def down
          raise ActiveRecord::IrreversibleMigration
        end
      end
    RUBY

    cache
  end

  let(:package_name) { 'packs/honey_production' }
end
