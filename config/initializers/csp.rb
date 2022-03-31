Rails.application.config.content_security_policy do |policy|
  # policy.default_src :self, :https
  # policy.font_src :self, :https, :data
  # policy.img_src :self, :https, :data
  # policy.object_src :none
  # policy.script_src :self, :https
  # policy.style_src :self, :https, :unsafe_inline
  # policy.report_uri "/csp-violation-report-endpoint"
  # TODO: Use scott helme report-uri
  # Determine where this can be put in an <iframe>
  policy.frame_ancestors 'self ohyay.co'
end

# Unset X-Frame-Options since we have CSP.
Rails.application.config.action_dispatch.default_headers.delete('X-Frame-Options')
