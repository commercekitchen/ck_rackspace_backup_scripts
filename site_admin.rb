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
    require "highline/import"

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

task = ask "Which task would you like to perform? \n 1 - Add new site \n 2 - Delete existing site \n 3 - Deactivate Site \n\n"

case task
  when '1'
    site_name = ask "Enter the Site Name: (i.e.  www.examplesite.com)"
    site_client_id = ask "Enter the Client Id: (not the cloud site id)"
    site_organization = ask "Enter the Organization Name: (i.e. Swallow Hill Music)"
    site_ftp_user = ask "Enter the FTP Username:"
    site_ftp_pass = ask "Enter the FTP Password:"
    site_rackspace_account_id = "601473"
    site_ftp_address = "ftp3.ftptoyoursite.com"
    database_exists = ask "Would you like to add a database? y/n"
    if database_exists == 'y' || database_exists == 'Y' || database_exists == 'yes' || database_exists == 'YES' 
      database_hostname = ask "Enter database hostname ip address: (i.e. 72.3.204.198)"
      database_name = ask "Enter database name:"
      database_username = ask "Enter database username:"
      database_password = ask "Enter database password:"
    end

    new_client = Client.new
    new_client.client_id = site_client_id
    new_client.organization = site_organization
    new_client.ftp_user = site_ftp_user
    new_client.ftp_pass = site_ftp_pass
    new_client.rackspace_account_id = site_rackspace_account_id
    if new_client.save
      puts "Client #{new_client.organization} successfully added"
    else
      puts "There was a problem, email kevin@commercekitchen.com for help"
    end

    new_site = CloudSite.new
    new_site.client_id = new_client.client_id
    new_site.site_name = site_name
    new_site.ftp_address = site_ftp_address
    new_site.active = 1
    if new_site.save
      puts "Site #{site_name} successfully added"
    else
      puts "There was a problem, email kevin@commercekitchen.com for help"
    end

    unless database_hostname.nil?
      new_db = CloudSiteDatabase.new
      new_db.cloud_site_id = new_site.cloud_site_id
      new_db.hostname = database_hostname
      new_db.database_name = database_name
      new_db.username = database_username
      new_db.password = database_password
      new_db.active = 1
      if new_db.save
        puts "Database #{new_db.database_name} successfully added"
      else
        puts "There was a problem, email kevin@commercekitchen.com for help"
      end
    end
  when '2'
    cloud_site_id = ask "Enter the cloud site ID"
    site_to_delete = CloudSite.find(cloud_site_id)
    
    #Destroy all databases tied to site
    site_to_delete.cloud_site_databases.each do |one_database|
      one_database.destroy
    end

    #Destroy client site
    site_to_delete.destroy

    puts "Site #{site_to_delete.site_name} deleted"
  when '3'
    cloud_site_id = ask "Enter the cloud site ID"
    cloud_site = CloudSite.find(cloud_site_id)
    cloud_site.active = 0
    #Deactivate associated databases too
    cloud_site.cloud_site_databases.each do |one_database|
      one_database.active = 0
      one_database.save
    end


    cloud_site.save
    puts "Site #{cloud_site.site_name} deactivated"
  else
    puts "Invalid Entry, bombing out..."
  end






