// Deploy at Resource Group scope.
targetScope = 'resourceGroup'

// ---------------------------------------------------------
// PARAMETERS
// Values that can change between environments.
// ---------------------------------------------------------

param location string = resourceGroup().location

param prefix string = 'webprod'

param adminUsername string = 'azureuser'

param sshPublicKey string

param vmSize string = 'Standard_D2s_v3'


// ---------------------------------------------------------
// VARIABLES
// Centralizing naming prevents inconsistencies.
// ---------------------------------------------------------

var vnetName = '${prefix}-vnet'
var subnetName = 'web'
var nsgName = '${prefix}-nsg'
var loadBalancerName = '${prefix}-lb'


// ---------------------------------------------------------
// NETWORK SECURITY GROUP
// ---------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location

  properties: {
    securityRules: [

      // Allow users to reach our web application.
      {
        name: 'AllowHTTP'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'

          sourcePortRange: '*'
          destinationPortRange: '80'

          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }

      // Azure Load Balancer must be able to health-check VMs.
      {
        name: 'AllowAzureLoadBalancerProbe'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'

          sourcePortRange: '*'
          destinationPortRange: '80'

          sourceAddressPrefix: 'AzureLoadBalancer'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}


// ---------------------------------------------------------
// NAT GATEWAY PUBLIC IP
// ---------------------------------------------------------

resource natPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${prefix}-nat-pip'
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}


// ---------------------------------------------------------
// NAT GATEWAY
// Gives backend VMs explicit outbound Internet connectivity.
// ---------------------------------------------------------

resource natGateway 'Microsoft.Network/natGateways@2024-05-01' = {
  name: '${prefix}-nat'
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    idleTimeoutInMinutes: 10

    publicIpAddresses: [
      {
        id: natPublicIp.id
      }
    ]
  }
}


// ---------------------------------------------------------
// VIRTUAL NETWORK
// ---------------------------------------------------------

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location

  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }

    subnets: [
      {
        name: subnetName

        properties: {
          addressPrefix: '10.20.1.0/24'

          // Attach security policy.
          networkSecurityGroup: {
            id: nsg.id
          }

          // Explicit outbound connectivity.
          natGateway: {
            id: natGateway.id
          }
        }
      }
    ]
  }
}


// ---------------------------------------------------------
// LOAD BALANCER PUBLIC IP
// ---------------------------------------------------------

resource lbPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${prefix}-lb-pip'
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {
    publicIPAllocationMethod: 'Static'
  }
}


// ---------------------------------------------------------
// LOAD BALANCER
// ---------------------------------------------------------

resource loadBalancer 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: loadBalancerName
  location: location

  sku: {
    name: 'Standard'
  }

  properties: {

    frontendIPConfigurations: [
      {
        name: 'frontend'

        properties: {
          publicIPAddress: {
            id: lbPublicIp.id
          }
        }
      }
    ]

    backendAddressPools: [
      {
        name: 'backend'
      }
    ]

    probes: [
      {
        name: 'httpProbe'

        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]

    loadBalancingRules: [
      {
        name: 'httpRule'

        properties: {

          protocol: 'Tcp'

          frontendPort: 80
          backendPort: 80

          frontendIPConfiguration: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/frontendIPConfigurations',
              loadBalancerName,
              'frontend'
            )
          }

          backendAddressPool: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/backendAddressPools',
              loadBalancerName,
              'backend'
            )
          }

          probe: {
            id: resourceId(
              'Microsoft.Network/loadBalancers/probes',
              loadBalancerName,
              'httpProbe'
            )
          }

          enableFloatingIP: false
          idleTimeoutInMinutes: 4

          // NAT Gateway handles outbound connectivity.
          disableOutboundSnat: true
        }
      }
    ]
  }
}


// ---------------------------------------------------------
// NETWORK INTERFACES
// Create two NICs using a Bicep loop.
// ---------------------------------------------------------

resource nics 'Microsoft.Network/networkInterfaces@2024-05-01' = [
  for i in range(0, 2): {

    name: '${prefix}-nic-${i + 1}'
    location: location

    properties: {

      ipConfigurations: [
        {
          name: 'ipconfig1'

          properties: {

            privateIPAllocationMethod: 'Dynamic'

            subnet: {
              id: resourceId(
                'Microsoft.Network/virtualNetworks/subnets',
                vnet.name,
                subnetName
              )
            }

            loadBalancerBackendAddressPools: [
              {
                id: resourceId(
                  'Microsoft.Network/loadBalancers/backendAddressPools',
                  loadBalancerName,
                  'backend'
                )
              }
            ]
          }
        }
      ]
    }

    dependsOn: [
      loadBalancer
    ]
  }
]


// ---------------------------------------------------------
// VIRTUAL MACHINES
// Create two identical Linux VMs.
// ---------------------------------------------------------

resource vms 'Microsoft.Compute/virtualMachines@2024-03-01' = [
  for i in range(0, 2): {

    name: '${prefix}-vm-${i + 1}'
    location: location

    properties: {

      hardwareProfile: {
        vmSize: vmSize
      }

      storageProfile: {

        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }

        osDisk: {
          createOption: 'FromImage'

          managedDisk: {
            storageAccountType: 'Standard_LRS'
          }
        }
      }

      osProfile: {

        computerName: '${prefix}-vm-${i + 1}'
        adminUsername: adminUsername

        // Install NGINX automatically.
        customData: base64(
          format(
            '#!/bin/bash\napt-get update\napt-get install -y nginx\necho "<h1>{0}-vm-{1}</h1>" > /var/www/html/index.html\nsystemctl enable nginx\nsystemctl start nginx\n',
            prefix,
            i + 1
          )
        )

        linuxConfiguration: {

          disablePasswordAuthentication: true

          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
        }
      }

      networkProfile: {

        networkInterfaces: [
          {
            id: nics[i].id
          }
        ]
      }
    }
  }
]


// ---------------------------------------------------------
// OUTPUTS
// Useful values returned after deployment.
// ---------------------------------------------------------

output loadBalancerPublicIp string = lbPublicIp.properties.ipAddress

output vmNames array = [
  for i in range(0, 2): '${prefix}-vm-${i + 1}'
]
