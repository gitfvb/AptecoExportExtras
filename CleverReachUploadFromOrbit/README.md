Put this new script between the `...` into the extras.xml

```
<Extras>
...
  <UploadToOrbit>
    <runcommand>
      <command>powershell.exe</command>
      <arguments>-ExecutionPolicy Bypass -File "C:\Users\Florian\Desktop\20200626\CR\cleverreach__21__extras_wrapper.ps1" -fileToUpload "{%directory%}{%filename%}.{%ext%}" -scriptPath "C:\Users\Florian\Desktop\20200626\CR"</arguments>
      <workingdirectory>C:\Users\Florian\Desktop\20200626\CR</workingdirectory>
      <waitforcompletion>true</waitforcompletion>
    </runcommand>
  </UploadToOrbit>
...
</Extras>
```