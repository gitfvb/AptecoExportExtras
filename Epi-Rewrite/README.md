* Replace `<connectionString>` with something like `Data Source=localhost\sqlexpress;Initial Catalog=ps_handel;Trusted_Connection=True;`
  * For more options and explanations see https://www.connectionstrings.com/sql-server/
* Change your `<scriptPath>` in the file `10__rewrite.ps1` to something like `D:\Apteco\Integration\episerver`
* Add another extras script to your `extras.xml`, in this example "CheckEpiFormat" and change the directories, if needed 

```XML
<Extras>
  <CheckEpiFormat>
    <runcommand>
      <command>powershell.exe</command>
      <arguments> -ExecutionPolicy Bypass -File "D:\Apteco\Integration\episerver\10__rewrite.ps1" -file "{%directory%}{%filename%}.{%ext%}"</arguments>
      <workingdirectory>D:\Apteco\Integration\episerver</workingdirectory>
      <waitforcompletion>true</waitforcompletion>
    </runcommand>
  </CheckEpiFormat>
</Extras>
```