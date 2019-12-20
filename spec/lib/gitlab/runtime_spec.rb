# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Runtime do
  context "when unknown" do
    it "identifies as :unknown" do
      expect(subject.name).to eq(:unknown)
    end
  end

  context "on multiple matches" do
    before do
      stub_const('::Puma', double)
      stub_const('::Rails::Console', double)
    end

    it "raises an exception when trying to identify" do
      expect { subject.name }.to raise_error(RuntimeError, "Ambiguous process match: [:puma, :console]")
    end
  end

  context "puma" do
    let(:puma_type) { double('::Puma') }

    before do
      stub_const('::Puma', puma_type)
    end

    it "identifies itself" do
      expect(subject.name).to eq(:puma)
      expect(subject.puma?).to be(true)
    end

    it "does not identify as others" do
      expect(subject.unicorn?).to be(false)
      expect(subject.sidekiq?).to be(false)
      expect(subject.console?).to be(false)
    end
  end

  context "unicorn" do
    let(:unicorn_type) { Module.new }

    before do
      stub_const('::Unicorn', unicorn_type)
    end

    it "identifies itself" do
      expect(subject.name).to eq(:unicorn)
      expect(subject.unicorn?).to be(true)
    end

    it "does not identify as others" do
      expect(subject.puma?).to be(false)
      expect(subject.sidekiq?).to be(false)
      expect(subject.console?).to be(false)
    end
  end

  context "sidekiq" do
    let(:sidekiq_type) { double('::Sidekiq') }

    before do
      stub_const('::Sidekiq', sidekiq_type)
      allow(sidekiq_type).to receive(:server?).and_return(true)
    end

    it "identifies itself" do
      expect(subject.name).to eq(:sidekiq)
      expect(subject.sidekiq?).to be(true)
    end

    it "does not identify as others" do
      expect(subject.unicorn?).to be(false)
      expect(subject.puma?).to be(false)
      expect(subject.console?).to be(false)
    end
  end

  context "console" do
    let(:console_type) { double('::Rails::Console') }

    before do
      stub_const('::Rails::Console', console_type)
    end

    it "identifies itself" do
      expect(subject.name).to eq(:console)
      expect(subject.console?).to be(true)
    end

    it "does not identify as others" do
      expect(subject.unicorn?).to be(false)
      expect(subject.sidekiq?).to be(false)
      expect(subject.puma?).to be(false)
    end
  end
end
