    #Sets the loadpath to the current dir
    $:.unshift File.dirname(__FILE__)

    require 'rubygems'
    require 'active_record'
    require 'ap'
    require 'logger'
    require 'fileutils'
    require 'pony'
    require 'open3'
    require 'BackupConfig'

    include Open3

#  Database Classes
    class RackspaceAccount < ActiveRecord::Base
      has_many   :clients
    end

    class Client < ActiveRecord::Base
      has_many    :cloud_sites
      belongs_to  :rackspace_account

    end

    class CloudSite < ActiveRecord::Base
      has_many     :cloud_site_databases
      belongs_to   :client
    end

   class CloudSiteDatabase < ActiveRecord::Base
     belongs_to    :cloud_site
   end

# Initialize Parameters
   $accounts = RackspaceAccount.all

def backup_databases
  #Backup Database

  # Loop through clients
  $accounts.each do |account|
    account.clients.each do |client|
      $log.debug("Starting backups for client #{client.organization}")

      # Loop through each site
      client.cloud_sites.each do |site|
        $log.debug("Starting database backups for site #{site.site_name}")
        error_message = ""

        #Clear directory and create new one
        begin
          database_backup_path = File.join($databases_base_path, site.site_name)
          if database_backup_path == "/"
            abort("Database backup failed, database path = '/'")  #safety check to ensure we don't rm -rf /
          end
          FileUtils.rm_rf("#{database_backup_path}")
          FileUtils.mkpath "#{database_backup_path}"
        rescue Exception => e
          error_message += "Database backup error for site #{site.site_name} ... #{e}"
        end

        #Loop through each databases
        unless site.cloud_site_databases.empty?
          site.cloud_site_databases.each do |database|
            begin
              error_message = ""
              # Backup Databases
              stdin, stdout, stderr = popen3("mysqldump -h %s -u%s -p'%s' --opt %s | gzip -9 > %s/%s.`date --iso-8601`.gz" % [database.hostname, database.username, database.password, database.database_name, database_backup_path, database.database_name])
	      stdout.sync = true
              $log.debug(stdout.read)
              stdin.close
              error_message += stderr.read
            rescue Exception => e
              error_message += "Database backup error for database #{database.database_name} ... #{e}"
            end

            #Write Errors to logs
            unless error_message.empty?
              $log.error error_message
              $email_error_message += error_message
            end

          $log.debug("Finish database backups for database #{database.database_name}")
          end
        end
      end
    end
  end
end

def backup_files

  # Loop through clients
  $accounts.each do |account|
    account.clients.each do |client|
      $log.debug("Starting backups for client #{client.organization}")

      # Loop through each site
      client.cloud_sites.each do |site|
        begin
          error_message = ""
          $log.debug("Starting file backups for site #{site.site_name}")

          # Backup Files
          file_backup_path = File.join($files_base_path,site.site_name)
          stdin, stdout, stderr = popen3(%q[mkdir -p %s ; touch %s; lftp -vvv -c 'open -e "set ftp:list-options -a; mirror -a --parallel=10 -v %s %s" -u %s,%s %s']  % [file_backup_path, file_backup_path, site.site_name, file_backup_path, client.ftp_user, client.ftp_pass, site.ftp_address])
	  ap stdout.readlines
          stdout.sync = true
          $log.debug(stdout.read)
          stdin.close
          error_message += stderr.read
        rescue Exception => e
          error_message += "File backup error for site #{site.site_name}... #{e}"
        end

        #Write Errors to logs
        unless error_message.empty?
          $log.error error_message
          $email_error_message += error_message
        end
        $log.debug("Finish file backups for site #{site.site_name}")
      end
    end
  end
end

def send_error_email
        $log.debug("Sending out error email")
        Pony.mail(:to => TO_EMAIL, :from => FROM_EMAIL, :subject => "Error running rackspace backups", :body => $email_error_message)
        $log.debug("Finish sending out error email")
end


#Run Backups
backup_databases
backup_files
unless $email_error_message.empty?
send_error_email
end


