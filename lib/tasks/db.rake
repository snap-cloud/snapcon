# frozen_string_literal: true

namespace :db do
  desc 'Bootstrap the database for the current RAILS_ENV (create, setup & seed if the database does not exist)'
  task bootstrap: :environment do
    Rake::Task['db:create'].invoke
    if ActiveRecord::Base.connection.tables.empty?
      puts 'Bootstrapping the database...'
      Rake::Task['db:setup'].invoke
      Rake::Task['db:seed'].invoke
    else
      puts 'Database exists, skipping bootstrap...'
    end
  end

  desc 'Import a given file into the database'
  task :import, [:path] => :environment do |_t, args|
    dump_path = args.path
    connection_config = ActiveRecord::Base.connection_db_config
    config = connection_config.configuration_hash

    case connection_config.adapter
    when 'postgresql'
      system("PGPASSWORD=#{config[:password]} pg_restore " \
             '--verbose --clean --no-acl --no-owner ' \
             "--username=#{config[:username]} " \
             "-d #{config[:database]} #{dump_path}")
    when 'mysql', 'mysql2'
      system("mysql -u #{config[:username]} " \
             "-p#{config[:password]} #{config[:database]} < #{dump_path}")
    else
      raise NotImplementedError, "An importer hasn't been implemented for: " \
                                 "#{connection_config.adapter}"
    end
  end
end
