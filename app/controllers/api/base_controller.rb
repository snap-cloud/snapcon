# frozen_string_literal: true

module Api
  class BaseController < ApplicationController
    protect_from_forgery with: :exception
  end
end
