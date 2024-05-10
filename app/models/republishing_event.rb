class RepublishingEvent < ApplicationRecord
  belongs_to :user

  validates :action, presence: true
  validates :reason, presence: true
end
