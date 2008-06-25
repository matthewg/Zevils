class Meal < ActiveRecord::Base
  validates_presence_of :name
  has_many :people
end
