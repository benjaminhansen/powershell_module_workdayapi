function ConvertFrom-WorkdayWorkerXml {
<#
.Synopsis
   Converts Workday Worker XML into a custom object.
#>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    Param (
        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0)]
        [xml[]]$Xml
    )

    Begin {
        $WorkerObjectTemplate = [pscustomobject][ordered]@{
            WorkerWid             = $null
            Active                = $null
            WorkerDescriptor      = $null
            PreferredName         = $null
            PreferredFirstName    = $null
            PreferredMiddleName   = $null
            PreferredLastName     = $null
            FirstName             = $null
            MiddleName            = $null
            LastName              = $null
            WorkerType            = $null
            WorkerId              = $null
            UserId                = $null
            NationalId            = $null
            OtherId               = $null
            Phone                 = $null
            Email                 = $null
            BusinessTitle         = $null
            JobProfileName        = $null
            Location              = $null
            WorkerTypeReference   = $null
            Manager               = $null
            Company               = $null
            PayGroup              = $null
            Supervisory           = $null
            RawXML                = $null
            WorkerStatus          = $null
            PrimaryJob            = $null
            UniversalId           = $null
            RawAddressData        = $null
            AddressZip            = $null
            AddressCity           = $null
            AddressState          = $null
            AddressLine1          = $null
            AddressLine2          = $null
        }
        $WorkerObjectTemplate.PsObject.TypeNames.Insert(0, "Workday.Worker")
    }

    Process {
        foreach ($elements in $Xml) {
            foreach ($x in $elements.SelectNodes('//wd:Worker', $NM)) {
                $o = $WorkerObjectTemplate.PsObject.Copy()

                $referenceId = $x.Worker_Reference.ID | Where-Object {$_.type -ne 'WID'}

                $o.WorkerWid            = $x.Worker_Reference.ID | Where-Object {$_.type -eq 'WID'} | Select-Object -ExpandProperty '#text'
                $o.WorkerDescriptor     = $x.Worker_Descriptor
                $o.PreferredName        = $x.Worker_Data.Personal_Data.Name_Data.Preferred_Name_Data.Name_Detail_Data.Formatted_Name
                $o.PreferredLastName    = $x.Worker_Data.Personal_Data.Name_Data.Preferred_Name_Data.Name_Detail_Data.Last_Name
                $o.PreferredFirstName   = $x.Worker_Data.Personal_Data.Name_Data.Preferred_Name_Data.Name_Detail_Data.First_Name
                $o.PreferredMiddleName  = $x.Worker_Data.Personal_Data.Name_Data.Preferred_Name_Data.Name_Detail_Data.Middle_Name
                $o.FirstName            = $x.Worker_Data.Personal_Data.Name_Data.Legal_Name_Data.Name_Detail_Data.First_Name
                $o.MiddleName           = $x.Worker_Data.Personal_Data.Name_Data.Legal_Name_Data.Name_Detail_Data.Middle_Name
                $o.LastName             = $x.Worker_Data.Personal_Data.Name_Data.Legal_Name_Data.Name_Detail_Data.Last_Name
                $o.WorkerType           = $referenceId.type
                $o.WorkerId             = $referenceId.'#text'
                $o.RawXML               = [XML]$x.OuterXml

                $o.Phone        = @(Get-WorkdayWorkerPhone -WorkerXml $x.OuterXml)
                $o.Email        = @(Get-WorkdayWorkerEmail -WorkerXml $x.OuterXml)
                $o.NationalId   = @(Get-WorkdayWorkerNationalId -WorkerXml $x.OuterXml)
                $o.OtherId      = @(Get-WorkdayWorkerOtherId -WorkerXml $x.OuterXml)
                $o.UserId       = $x.Worker_Data.User_ID

                # The methods SelectNodes and SelectSingleNode have access to the entire XML document and require anchoring with "./" to work as expected.
                $workerEmploymentData = $x.SelectSingleNode('./wd:Worker_Data/wd:Employment_Data', $NM)
                if ($null -ne $workerEmploymentData) {
                    $o.Active = $workerEmploymentData.Worker_Status_Data.Active -eq '1'
                    $o.WorkerStatus = $workerEmploymentData.Worker_Status_Data
                }

                $workerJobData = $x.SelectSingleNode('./wd:Worker_Data/wd:Employment_Data/wd:Worker_Job_Data', $NM)
                if ($null -ne $workerJobData) {
                    $o.BusinessTitle = $workerJobData.Position_Data.Business_Title
                    $o.JobProfileName = $workerJobData.Position_Data.Job_Profile_Summary_Data.Job_Profile_Name
                    $o.Location = $workerJobData.SelectNodes('./wd:Position_Data/wd:Business_Site_Summary_Data/wd:Name', $NM).InnerText
                    $o.WorkerTypeReference = $workerJobData.SelectNodes('./wd:Position_Data/wd:Worker_Type_Reference/wd:ID[@wd:type="Employee_Type_ID"]', $NM).InnerText
                    $manager = $workerJobData.Position_Data.Manager_as_of_last_detected_manager_change_Reference.ID |
                        Where-Object {$_.type -ne 'WID'} |
                            Select-Object @{Name='WorkerType';Expression={$_.type}}, @{Name='WorkerID';Expression={$_.'#text'}}
                    $o.Manager = $manager

                    $o.Company = $workerJobData.SelectNodes('./wd:Position_Organizations_Data/wd:Position_Organization_Data/wd:Organization_Data[wd:Organization_Type_Reference/wd:ID[@wd:type="Organization_Type_ID" and . = "Company"]]', $NM) | Select-Object -ExpandProperty Organization_Name -First 1
                    $o.PayGroup = $workerJobData.SelectNodes('./wd:Position_Organizations_Data/wd:Position_Organization_Data/wd:Organization_Data[wd:Organization_Type_Reference/wd:ID[@wd:type="Organization_Type_ID" and . = "Pay_Group"]]', $NM) | Select-Object -ExpandProperty Organization_Name -First 1
                    $o.Supervisory = $workerJobData.SelectNodes('./wd:Position_Organizations_Data/wd:Position_Organization_Data/wd:Organization_Data[wd:Organization_Type_Reference/wd:ID[@wd:type="Organization_Type_ID" and . = "Supervisory"]]', $NM) | Select-Object -ExpandProperty Organization_Name -First 1

                    $o.PrimaryJob = [boolean]$workerJobData.SelectSingleNode('./@wd:Primary_Job', $NM).'#text'

                    $o.RawAddressData = $workerJobData.SelectNodes('./wd:Position_Data/wd:Business_Site_Summary_Data/wd:Address_Data', $NM)
                    $o.AddressZip = $o.RawAddressData.Postal_Code
                    $o.AddressCity = $o.RawAddressData.Municipality
                    $o.AddressState = $o.RawAddressData.Country_Region_Descriptor
                    $o.AddressLine1 = $o.RawAddressData.Address_Line_Data[0].'#text'
                    $o.AddressLine2 = $o.RawAddressData.Address_Line_Data[1].'#text'
                }

                if($null -ne $x.SelectSingleNode('./wd:Universal_Identifier_Reference/wd:ID[@wd:type="Universal_Identifier_ID"]/text()', $NM)) {
                    $o.UniversalId = $x.SelectSingleNode('./wd:Universal_Identifier_Reference/wd:ID[@wd:type="Universal_Identifier_ID"]/text()', $NM).Value
                }

                Write-Output $o
            }
        }
    }
}
