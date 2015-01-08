class Treatment < ActiveRecord::Base
  belongs_to :sample
  belongs_to :specimen
  belongs_to :unit
  belongs_to :time_after_treatment_unit, class_name: 'Unit'

  belongs_to :measured_item
  belongs_to :compound

  alias_method :treatment_type, :measured_item

  validates :sample, presence: true

  def time_after_treatment_with_unit
    time_after_treatment.nil? ? "" : "#{time_after_treatment} (#{time_after_treatment_unit.symbol}s)"
  end

  def value_with_unit
    start_value.nil? ? "" : start_value.to_s + " " + (end_value.nil? ? "" : "- " + end_value.to_s + " ") + unit.symbol
  end

end
