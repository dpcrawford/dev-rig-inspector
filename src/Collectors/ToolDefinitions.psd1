@{
    Tools = @(
        @{ Id = 'powershell'; DisplayName = 'PowerShell'; Command = 'pwsh'; VersionArguments = @('--version') },
        @{ Id = 'git'; DisplayName = 'Git'; Command = 'git'; VersionArguments = @('--version') },
        @{ Id = 'gh'; DisplayName = 'GitHub CLI'; Command = 'gh'; VersionArguments = @('--version') },
        @{ Id = 'python'; DisplayName = 'Python'; Command = 'python'; VersionArguments = @('--version') },
        @{ Id = 'uv'; DisplayName = 'uv'; Command = 'uv'; VersionArguments = @('--version') },
        @{ Id = 'node'; DisplayName = 'Node.js'; Command = 'node'; VersionArguments = @('--version') },
        @{ Id = 'npm'; DisplayName = 'npm'; Command = 'npm'; VersionArguments = @('--version') },
        @{ Id = 'dotnet'; DisplayName = '.NET'; Command = 'dotnet'; VersionArguments = @('--version') },
        @{ Id = 'vscode'; DisplayName = 'VS Code'; Command = 'code'; VersionArguments = @('--version') }
    )
}