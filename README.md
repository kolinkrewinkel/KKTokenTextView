KKTokenTextView
===============

UITextView subclass which supports inline tokens and puncutational corrections.

This was designed for one particular use case (which the demo utilizes). It should support many others as well, however it wouldn't surprise me if the API did not work well for other models. The base is here, however, so even if it feels like the API is way off, it's doable for your sitaution most likely (when I say base, I mean the string management, basically. 'Cause that's pretty solid, pretty much anything can be wrapped around it.) Feel free to nudge me about issues that you have and absolutely do not hesitate to fork and submit a pull request.

**License**  
See LICENSE.md.

**Usage**      

1. Add this as a submodule.  
2. Drag the project into your workspace or project.  
3. Add it as a linked library in Target Settings.
4. Configure your header search paths to include the text view. *See the demo for an example of how to assign a relative path to the actual code so you can import it like a standard library.*
5. Enjoy token-y punctutationally-correct UITextView goodness.

**Demo Screenshots**  
![image](https://files.app.net/7v8h27uV.png)
![image](https://files.app.net/7v8pKt54.png)
![image](https://files.app.net/7v8zsDz-.png)
![image](https://files.app.net/7v8rdjm1.png)