# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::FileCache do
  subject(:file_cache) { described_class.new }

  define_method(:sources_in) do |file_name, class_name: '::Billing::Invoice'|
    file_cache
      .get_full_sources(file_name: file_name, class_name: class_name)
      .map { |node| [node.loc.line, node.source] }
  end

  describe '#get_full_sources' do
    it 'finds references in the Ruby code of an ERB template, on their template lines' do
      write_file('app/views/invoices/show.html.erb', <<~ERB)
        <div class="invoice">
          <%# Billing::Invoice in a comment is not a reference %> <%= Billing::Invoice.count %>
          <p>Escaped: <%%= Billing::Invoice %></p>
          <% if Billing::Invoice.overdue?(@account) %>
            <p><%= Billing::Invoice.for(@account).total %></p>
          <% end %>
          <%= form_with model: @account do |form| %>
            <%= form.text_field :name %> <%= Billing::Invoice.statuses.first %>
          <% end %>
        </div>
      ERB

      expect(sources_in('app/views/invoices/show.html.erb')).to eq(
        [
          [2, 'Billing::Invoice.count'],
          [4, 'Billing::Invoice.overdue?(@account)'],
          [5, 'Billing::Invoice.for(@account).total'],
          [8, 'Billing::Invoice.statuses.first']
        ]
      )
    end

    %w[app/views/invoices/show.js.erb app/views/invoices/show.erb].each do |file_name|
      it "finds references in #{file_name}" do
        write_file(file_name, "var count = <%= Billing::Invoice.count %>;\n")

        expect(sources_in(file_name)).to eq([[1, 'Billing::Invoice.count']])
      end
    end

    it 'finds a reference that is the only code in a template' do
      write_file('app/views/invoices/_name.html.erb', "<p><%= Billing::Invoice %></p>\n")

      expect(sources_in('app/views/invoices/_name.html.erb')).to eq([[1, 'Billing::Invoice']])
    end

    it 'finds nothing, without a warning, in an ERB template without Ruby code' do
      write_file('app/views/pages/about.html.erb', "<p>About</p>\n")

      expect { sources_in('app/views/pages/about.html.erb') }.not_to output.to_stderr
      expect(sources_in('app/views/pages/about.html.erb')).to eq([])
    end

    it 'finds nothing, without a warning, in a Ruby file with only comments' do
      write_file('app/models/invoice.rb', "# frozen_string_literal: true\n")

      expect { sources_in('app/models/invoice.rb') }.not_to output.to_stderr
      expect(sources_in('app/models/invoice.rb')).to eq([])
    end

    %w[app/models/invoice.rb app/views/invoices/show.html.erb].each do |file_name|
      it "finds nothing, without a warning, when #{file_name} does not exist" do
        expect { sources_in(file_name) }.not_to output.to_stderr
        expect(sources_in(file_name)).to eq([])
      end
    end

    it 'warns, once, that it found nothing in a file it could not parse' do
      write_file('app/views/invoices/show.html.erb', <<~ERB)
        <% if Billing::Invoice.overdue?(@account) %>
          <p>Overdue</p>
        <% end %>
        <% end %>
      ERB

      expect do
        sources_in('app/views/invoices/show.html.erb')
        sources_in('app/views/invoices/show.html.erb', class_name: '::Billing::Payment')
      end.to output(%r{\ACould not parse app/views/invoices/show\.html\.erb:4 \(.+\), so its violations are not included\n\z})
        .to_stderr
      expect(sources_in('app/views/invoices/show.html.erb')).to eq([])
    end

    %w[
      lib/tasks/billing.rake app/views/invoices/show.xml.builder billing.gemspec config.ru Gemfile Rakefile
    ].each do |file_name|
      it "finds references in #{file_name}" do
        write_file(file_name, "Billing::Invoice.find(1)\n")

        expect(sources_in(file_name)).to eq([[1, 'Billing::Invoice.find(1)']])
      end
    end

    it 'finds nothing in a file that packwerk does not parse' do
      write_file('Gemfile.lock', "Billing::Invoice.find(1)\n")

      expect(sources_in('Gemfile.lock')).to eq([])
    end

    it 'gets the calls on each use of the constant, rather than on an equal use around it' do
      write_file('app/models/account.rb', <<~RUBY)
        class Account < ApplicationRecord
          def merge = Billing::Invoice.merge(Billing::Invoice)

          def latest = Billing::Invoice.latest.then { Billing::Invoice.latest }
        end
      RUBY

      expect(sources_in('app/models/account.rb')).to eq(
        [
          [2, 'Billing::Invoice.merge(Billing::Invoice)'],
          [2, 'Billing::Invoice'],
          [4, 'Billing::Invoice.latest.then'],
          [4, 'Billing::Invoice.latest']
        ]
      )
    end

    it 'finds no use of a constant where it is only the namespace of another' do
      write_file('app/models/account.rb', <<~RUBY)
        class Account < ApplicationRecord
          def billing = Billing.for(self)

          def invoice = Billing::Invoice.for(self)
        end
      RUBY

      expect(sources_in('app/models/account.rb', class_name: '::Billing')).to eq([[2, 'Billing.for(self)']])
    end
  end

  describe '#get_full_source_at' do
    define_method(:source_at) do |line, column|
      file_cache.get_full_source_at(file_name: 'app/models/account.rb', line: line, column: column)&.source
    end

    before do
      write_file('app/models/account.rb', <<~RUBY)
        class Account < ApplicationRecord
          has_many :invoices, dependent: :destroy

          def overdue_lines = Billing::Invoice::Line.overdue_for(self)

          def summary = "Échéance ⏰ \#{Billing::Invoice.due_for(self).count}"
        end
      RUBY
    end

    it 'finds the outermost constant that starts there, with the calls chained on it' do
      expect(source_at(4, 22)).to eq('Billing::Invoice::Line.overdue_for(self)')
    end

    it 'counts the column in bytes, as pks does' do
      expect(source_at(6, 34)).to eq('Billing::Invoice.due_for(self).count')
    end

    it 'finds the call when no constant starts there, as for an association' do
      expect(source_at(2, 2)).to eq('has_many :invoices, dependent: :destroy')
    end

    it 'finds nothing when nothing starts there' do
      expect(source_at(4, 23)).to be_nil
    end

    it 'finds the calls on the constant there, rather than on an equal one around it' do
      write_file('app/models/account.rb', "def merge = Billing::Invoice.merge(Billing::Invoice)\n")

      expect(source_at(1, 35)).to eq('Billing::Invoice')
    end

    it 'finds nothing in a file that does not exist or does not parse' do
      write_file('app/models/broken.rb', "Billing::Invoice.find(\n")

      expect(file_cache.get_full_source_at(file_name: 'app/models/missing.rb', line: 1, column: 0)).to be_nil
      expect { expect(file_cache.get_full_source_at(file_name: 'app/models/broken.rb', line: 1, column: 0)).to be_nil }
        .to output(%r{\ACould not parse app/models/broken\.rb}).to_stderr
    end
  end
end
