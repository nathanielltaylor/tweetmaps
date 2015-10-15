require 'rails_helper'

RSpec.describe User, type: :model do
  it { should have_many(:searches) }
  it { should have_many(:recommendations) }
  it { should validate_presence_of(:email) }
  it { should validate_presence_of(:username) }
  it { should validate_presence_of(:password) }
end
