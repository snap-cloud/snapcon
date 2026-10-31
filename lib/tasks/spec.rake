# frozen_string_literal: true

unless Rails.env.production?
  # rspec-rails already defines spec:<dir> tasks; clear them so ours don't run the suite a second time.
  %w[ability models controllers features].each do |name|
    Rake::Task["spec:#{name}"].clear if Rake::Task.task_defined?("spec:#{name}")
  end

  namespace :spec do
    desc 'rspec ability'
    task :ability do
      sh 'bundle exec rspec --format documentation spec/ability'
    end
    desc 'run the cucumber tests'
    task :cucumber do
      sh 'CUCUMBER_PUBLISH_QUIET=true bundle exec cucumber'
    end
    desc 'rspec models'
    task :models do
      sh 'bundle exec rspec --format documentation spec/models'
    end
    desc 'rspec controllers'
    task :controllers do
      sh 'bundle exec rspec --format documentation spec/controllers'
    end
    desc 'rspec features'
    task :features do
      sh 'bundle exec rspec --format documentation spec/features'
    end
    desc 'rspec the leftovers'
    task :leftovers do
      sh 'bundle exec rspec --format documentation --exclude-pattern "spec/{models,features,controllers,ability}/**/*_spec.rb"'
    end
  end
end
