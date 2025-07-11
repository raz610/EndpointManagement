### PowerShell Script to Set Network Category to Private

This README provides an overview of a PowerShell script designed to change the network category of a connected network adapter to **Private**.

#### **Purpose**

The primary function of this script is to programmatically override the network profile of a Windows machine and set it to "Private." This is a useful task for endpoint management, ensuring that a device on a trusted network (like a home or work network) has the correct, less restrictive firewall rules and features like network discovery enabled.

#### **Usage**

To execute this PowerShell script, follow these steps:

1.  **Open PowerShell with Administrator Privileges:** The script requires elevated permissions to modify system-level network settings. You must open PowerShell as an administrator by right-clicking the PowerShell icon and selecting "Run as administrator."

2.  **Navigate to the Script Directory:** Use the `cd` command to change to the directory where the script file is located.

3.  **Run the Script:** Execute the script using one of the following methods:

      * If you know the script's filename (e.g., `Set-NetworkPrivate.ps1`), simply run it with a relative path:
        ```powershell
        .\Set-NetworkPrivate.ps1
        ```
#### **Important Considerations**

  * **Execution Policy:** If you encounter an error, your system's PowerShell Execution Policy might be preventing the script from running. You can temporarily change it with:
    ```powershell
    Set-ExecutionPolicy Bypass
    ```
     
  * **Permissions:** Without administrator rights, the script will fail to change the network profile and will likely throw an "Access is denied" error.
