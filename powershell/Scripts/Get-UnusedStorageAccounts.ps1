#!/usr/bin/env pwsh

Param(
  [Parameter()]
  [Int32] $TimeAgo = 3
)

# Connect to Azure
Connect-AzAccount

# Get the current date and time
$now = Get-Date

# Set the start time to 3 months ago
$startTime = $now.AddMonths(-$TimeAgo)

# Initialize an empty array to store the unused storage accounts
$unusedStorageAccounts = @()

# Get all storage accounts
$storageAccounts = Get-AzStorageAccount

# Iterate through each storage account
foreach ($storageAccount in $storageAccounts) {
  # Get the usage metrics for the storage account
  $metrics = Get-AzMetric -ResourceId $storageAccount.ResourceId -Metric "Transactions", "Ingress", "Egress" -DetailedOutput -StartTime $startTime -EndTime $now
  # Check if the usage metrics are empty
  if ($null -eq $metrics.Data) {
    # If the usage metrics are empty, add the storage account to the unused storage accounts array
    $unusedStorageAccounts += $storageAccount
  }
}

# Print the unused storage accounts
$unusedStorageAccounts
