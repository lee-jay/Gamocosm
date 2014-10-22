class StartMinecraftWorker
  include Sidekiq::Worker
  sidekiq_options retry: 0

  def perform(server_id)
    server = Server.find(server_id)
    minecraft = server.minecraft
    if !server.remote.exists?
      minecraft.log('Error starting server; remote_id is nil. Aborting')
      server.reset_partial
      return
    end
    if server.remote.error?
      minecraft.log("Error communicating with Digital Ocean while starting server; they responded with #{server.remote.error}. Aborting")
      server.reset_partial
      return
    end
    error = minecraft.node.resume
    if error
      minecraft.log("Error starting Minecraft on server: #{error}")
    end
    error = minecraft.server.remote.destroy_saved_snapshot
    if error
      minecraft.log("Error deleting saved snapshot on Digital Ocean after starting server; #{response}")
    end
    server.update_columns(pending_operation: nil)
  rescue ActiveRecord::RecordNotFound => e
    logger.info "Record in #{self.class} not found #{e.message}"
  rescue => e
    server.minecraft.log("Background job starting Minecraft failed: #{e}")
    server.reset_partial
    raise
  end
end
