#######################
<#
.SYNOPSIS
Creates a DataTable for an object
.DESCRIPTION
Creates a DataTable based on an objects properties.
.INPUTS
Object
    Any object can be piped to Out-DataTable
.OUTPUTS
   System.Data.DataTable
.EXAMPLE
$dt = Get-Alias | Out-DataTable
This example creates a DataTable from the properties of Get-Alias and assigns output to $dt variable
.NOTES
Adapted from script by Marc van Orsouw see link
Version History
v1.0   - Chad Miller - Initial Release
v1.1   - Chad Miller - Fixed Issue with Properties

***** HEAVILY MODIFIED FROM Chad's Script **** Mohit (2022.07.05)
**
**  Only using this to get data table def in format needed for Add-SQLTable.

.LINK
http://thepowershellguy.com/blogs/posh/archive/2007/01/21/powershell-gui-scripblock-monitor-script.aspx
#>
function Out-DataTableV2
{
    [CmdletBinding()]
    param([Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)] [PSObject[]]$InputObject)

    $dt = new-object Data.datatable  
    $First = $true 

    foreach ($object in $InputObject)
    {
        $DR = $DT.NewRow()  
        foreach($property in $object.PsObject.get_properties())
        {  
            if ($first)
            {  
                $Col =  new-object Data.DataColumn  
                $Col.ColumnName = $property.Name.ToString()
                $Col.DataType = $property.TypeNameOfValue
                $DT.Columns.Add($Col)
            }  
            if ($property.IsArray)
            { $DR.Item($property.Name) =$property.value | ConvertTo-XML -AS String -NoTypeInformation -Depth 1 }  
            else { $DR.Item($property.Name) = $property.value }  
        }  
        $DT.Rows.Add($DR)  
        $First = $false
        break
    }

    $dt.columns.Remove("RowError")                                                                                                                                                                         
    $dt.columns.Remove("RowState") 
    $dt.columns.remove("Table")
    $dt.columns.remove("ItemArray")
    $dt.columns.remove("HasErrors")
    Write-Output @(,($dt))

} #Out-DataTable