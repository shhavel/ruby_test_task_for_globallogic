require "sqlite3"
require "active_record"
require "shoulda"
require "database_cleaner"
require "factory_girl"

class CreateReservations < ActiveRecord::Migration
  def change
    create_table :reservations do |t|
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.integer :table_number, null: false
    end
  end
end

class Reservation < ActiveRecord::Base
  validates :start_time, :end_time, :table_number, presence: true
  validate :ensure_end_time_greater_than_start_time
  validate :ensure_table_number_not_overlapped

  scope :overlapped_with, ->(r) do
    rel = where(table_number: r.table_number).
    where(arel_table[:start_time].lt(r.end_time).and(arel_table[:end_time].gt(r.start_time)))
    r.persisted? ? rel.where(arel_table[:id].not_eq(r.id)) : rel
  end

private
  def ensure_end_time_greater_than_start_time
    return unless start_time && end_time
    errors.add(:end_time, 'should be greater than start time') if end_time < start_time
  end

  def ensure_table_number_not_overlapped
    return unless table_number && start_time && end_time
    errors.add(:table_number, 'overlapped within period of time') if self.class.overlapped_with(self).exists?
  end
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
CreateReservations.new.change

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.before(:each) { DatabaseCleaner.start }
  config.after(:each) { DatabaseCleaner.clean }
end

FactoryGirl.define do
  factory :reservation do
    start_time { 3.hours.since }
    end_time { 4.hours.since }
    table_number 4
  end
end

I18n.enforce_available_locales = false

describe Reservation do
  describe 'database table' do
    it { should have_db_column(:start_time).of_type(:datetime).with_options(null: false) }
    it { should have_db_column(:end_time).of_type(:datetime).with_options(null: false) }
    it { should have_db_column(:table_number).of_type(:integer).with_options(null: false) }
  end

  describe "validations" do
    it { should validate_presence_of :start_time }
    it { should validate_presence_of :end_time }
    it { should validate_presence_of :table_number }

    it "is valid with valid params" do
      expect(build(:reservation)).to be_valid
    end

    it "ensures that end_time greater than start_time" do
      reservation = build(:reservation, start_time: 4.hours.since, end_time: 3.hours.since)
      expect(reservation).to_not be_valid
      expect(reservation.errors[:end_time]).to be_present
    end

    it "checks new reservations for overbooking of the same table in the restaurant" do
      create(:reservation)
      expect(build(:reservation, start_time: 2.hours.since, end_time: 2.5.hours.since)).to be_valid
      overlapped_reservation = build(:reservation, start_time: 2.hours.since, end_time: 3.5.hours.since)
      expect(overlapped_reservation).to be_invalid
      expect(overlapped_reservation.errors[:table_number]).to be_present
    end

    it "table #10 cannot have 2 reservations for the same period of time" do
      create(:reservation)
      expect { create(:reservation) }.to raise_error
    end

    it "should check time overlap for both record creation and updates" do
      create(:reservation)
      reservation = create(:reservation, start_time: 4.5.hours.since, end_time: 6.hours.since)
      reservation.start_time = 3.5.hours.since
      expect(reservation).to be_invalid
      expect(reservation.errors[:table_number]).to be_present
      expect { reservation.update!(start_time: 3.5.hours.since) }.to raise_error
    end

    it "should be able to update itself (should ignore time overlap with itself)" do
      create(:reservation)
      reservation = create(:reservation, start_time: 4.5.hours.since, end_time: 6.hours.since)
      expect { reservation.update!(start_time: 5.hours.since) }.to_not raise_error
    end
  end
end
