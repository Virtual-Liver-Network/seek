class Sweep < ActiveRecord::Base

  has_many :runs, :class_name => 'TavernaPlayer::Run', :dependent => :destroy
  belongs_to :user
  belongs_to :workflow

  accepts_nested_attributes_for :runs

  attr_accessible :user_id, :workflow_id, :name, :runs_attributes

  before_destroy :cancel

  def cancel
    runs.each do |run|
      run.cancel unless run.finished?
    end
  end

  def cancelled?
    runs.all? { |run| run.cancelled? }
  end

  def finished?
    runs.all? { |run| run.finished? }
  end

  # HACK - This needs to say something real
  def state
    'doing stuff'
  end

end