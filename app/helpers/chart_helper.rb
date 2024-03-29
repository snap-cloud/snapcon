# frozen_string_literal: true

module ChartHelper
  def chart_values(distribution_hash)
    distribution_hash.collect do |key, data|
      [key, data['value']]
    end.to_h
  end

  def chart_colors(distribution_hash)
    distribution_hash.collect do |_key, data|
      data['color']
    end
  end
end
