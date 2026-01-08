class MessageLog < ApplicationRecord
  belongs_to :user
  belongs_to :flow_item
end
