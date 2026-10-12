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
  end
end
