# typed: false
# frozen_string_literal: true

RSpec.describe QueryPackwerk::RuleRewriter do
  context 'With positional arguments' do
    it 'anonymizes positional args' do
      expect(described_class.rewrite('all(1, 2, 3)')).to eq('all(_, _, _)')
    end

    it 'anonymizes complicated positional args' do
      code = "Model.find(1, 2, 's', a.b.c.d, Some::Nasty::Const.with(1))"
      expect(described_class.rewrite(code)).to eq('Model.find(_, _, _, _, _)')
    end

    it 'anonymizes splatted positional args' do
      code = "Model.find(1, 2, 's', *var)"
      expect(described_class.rewrite(code)).to eq('Model.find(_, _, _, *_)')
    end

    it 'anonymizes function args' do
      code = "Model.find(1, 2, 's', &var)"
      expect(described_class.rewrite(code)).to eq('Model.find(_, _, _, &_)')
    end
  end

  context 'With keyword arguments' do
    it 'anonymizes keyword args' do
      expect(described_class.rewrite('all(a: 1, b: 2)')).to eq('all(a: _, b: _)')
    end

    it 'anonymizes complicated keyword args' do
      code = 'Model.where(a: 1, b: { c: 2 }, d: A::B.c(1))'
      expect(described_class.rewrite(code)).to eq('Model.where(a: _, b: _, d: _)')
    end

    it 'anonymizes splatted kwargs' do
      code = 'Model.where(a: 1, b: { c: 2 }, **d)'
      expect(described_class.rewrite(code)).to eq('Model.where(a: _, b: _, **_)')
    end
  end

  context 'With both types of arguments' do
    it 'anonymizes mixed args' do
      expect(described_class.rewrite('all(1, a: 1, b: 2)')).to eq('all(_, a: _, b: _)')
    end

    it 'anonymizes complicated keyword args' do
      code = <<~RUBY
        Model.where(
          1,
          2,
          's',
          a.b.c.d,
          Some::Nasty::Const.with(1),
          *and_splats,
          a: 1,
          b: { c: 2 },
          d: A::B.c(1),
          **with_keyword_splats,
          &and_a_function
        )
      RUBY

      expect(described_class.rewrite(code)).to eq <<~RUBY.chomp
        Model.where(_, _, _, _, _, *_, a: _, b: _, d: _, **_, &_)
      RUBY
    end
  end
end
