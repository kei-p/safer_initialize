require 'safer_initialize/active_record/extensions'

RSpec.describe SaferInitialize::ActiveRecord::Extensions do
  describe '.safer_initialize' do
    it 'If non active, raise SaferInitialize::Error' do
      class ActiveCheck < DummyRecord
        attr_accessor :deleted_at

        safer_initialize :active?, message: 'Not active project!'

        def active?
          deleted_at.nil?
        end
      end

      expect {
        ActiveCheck.new(deleted_at: nil)
      }.not_to raise_error

      expect {
        ActiveCheck.new(deleted_at: Time.current)
      }.to raise_error(SaferInitialize::Error, 'Not active project!')
    end

    it 'raise SaferInitialize::Error with proc message' do
      class MessageWithProc < DummyRecord
        attr_accessor :deleted_at, :name

        safer_initialize :active?, message: ->(record) { "#{record.name} is not active!" }

        def active?
          deleted_at.nil?
        end
      end

      expect {
        MessageWithProc.new(deleted_at: Time.current, name: 'safer_initialize')
      }.to raise_error(SaferInitialize::Error, 'safer_initialize is not active!')
    end
  end

  describe '.defer' do
    after { SaferInitialize::Globals.reset }

    it 'delays check evaluation until the block finishes, in enqueue order' do
      evaluated = []
      klass = Class.new(DummyRecord) do
        attr_accessor :label
        safer_initialize :ok?
        define_method(:ok?) { evaluated << label; true }
      end

      SaferInitialize.defer do
        klass.new(label: :a)
        klass.new(label: :b)
        expect(evaluated).to be_empty
      end

      expect(evaluated).to eq(%i[a b])
    end

    it 'flushes at the block end and raises on violation' do
      klass = Class.new(DummyRecord) do
        safer_initialize(message: 'nope') { false }
      end

      expect {
        SaferInitialize.defer { klass.new }
      }.to raise_error(SaferInitialize::Error, 'nope')
    end

    it 'stops at the first raised check (enqueue order)' do
      count = 0
      klass = Class.new(DummyRecord) do
        safer_initialize { count += 1; false }
      end

      expect {
        SaferInitialize.defer do
          klass.new
          klass.new
        end
      }.to raise_error(SaferInitialize::Error)
      expect(count).to eq(1)
    end

    it 'cannot be nested' do
      expect {
        SaferInitialize.defer { SaferInitialize.defer {} }
      }.to raise_error(SaferInitialize::Error, 'SaferInitialize.defer cannot be nested')
    end

    it 'discards the queue without flushing when the block raises' do
      evaluated = false
      klass = Class.new(DummyRecord) do
        safer_initialize { evaluated = true; false }
      end

      expect {
        SaferInitialize.defer do
          klass.new
          raise 'boom'
        end
      }.to raise_error('boom')
      expect(evaluated).to be(false)
      expect(SaferInitialize::Globals.deferring?).to be(false)
    end

    it 'skips enqueue for records loaded inside with_safe' do
      ran = false
      klass = Class.new(DummyRecord) do
        safer_initialize { ran = true; false }
      end

      expect {
        SaferInitialize.defer do
          SaferInitialize.with_safe { klass.new }
        end
      }.not_to raise_error
      expect(ran).to be(false)
    end
  end
end
