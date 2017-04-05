defmodule Gittp.Git do
    use GenServer
    require Logger
    # client functions

    def start_link({:local_repo_path, local_repo_path}, {:remote_repo_url, remote_repo_url}) do
        GenServer.start_link(__MODULE__, [{:local_repo_path, local_repo_path}, {:remote_repo_url, remote_repo_url}], name: :git)
    end

    def content(pid, path) do
        GenServer.call(pid, {:read, path})
    end

    def write(pid, body = %{"content" => content, "checksum" => checksum, "path" => path, "commit_message" => commit_message}) do
        GenServer.call(pid, {:write, body})
    end

    # server functions

    def init(local_repo_path: local_repo_path, remote_repo_url: remote_repo_url) do
        repo = if File.exists?(local_repo_path) do
                    repo = Git.new local_repo_path
                    Git.remote repo, ["add", "upstream", remote_repo_url]
                    Git.pull repo, ~w(--rebase upstream master)
                    Logger.info "pulled latest changes from " <> local_repo_path            
                    repo
                else
                    {:ok, repo} = Git.clone [remote_repo_url, local_repo_path]
                    Git.remote repo, ["add", "upstream", remote_repo_url]    
                    Logger.info "cloned " <> remote_repo_url     
                    repo
                end    
        
        {:ok, {repo}}
    end

    def handle_call({:read, path}, _from, {repo}) do        
        case Gittp.Repo.content(repo, path) do
            {:ok, content} -> {:reply, %{"content" => content, "checksum" => Gittp.Utils.hash_string(content), "path" => path}, {repo}}
            {:error, message} -> {:reply, message, {repo}}    
        end 
    end

    def handle_call({:write, %{"content" => content, "checksum" => checksum, "path" => file_path, "commit_message" => commit_message}}, _from, {repo}) do     
        case checksum_valid?(checksum, repo, file_path) do
            false -> {:reply, {:error, :checksum_mismatch}, {repo}}            
            _ -> Gittp.Repo.write(repo, file_path, content, commit_message)
        end
    end

    defp checksum_valid?(checksum, repo, file_path) do
        full_path = Gittp.Repo.full_path(repo, file_path)
        File.exists?(full_path) and Gittp.Utils.hash_file(full_path) == checksum
    end    
end