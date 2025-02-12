all: index.md 0_intro.ipynb 1_provision_gui.ipynb 2_provision_cli.ipynb 3_docker.ipynb 4_kubernetes.ipynb 5_delete.ipynb

clean: 
	rm index.md 0_intro.ipynb 1_provision_gui.ipynb 2_provision_cli.ipynb 3_docker.ipynb 4_kubernetes.ipynb 5_delete.ipynb

index.md: snippets/*.md images/*
	cat snippets/intro.md \
		snippets/provision_gui.md \
		snippets/provision_cli.md \
		snippets/docker.md \
		snippets/kubernetes.md \
		snippets/delete.md \
		> index.tmp.md
	grep -v '^:::' index.tmp.md > index.md
	rm index.tmp.md
	cat snippets/extras.md >> index.md
	cat snippets/contributors.md >> index.md
	cat snippets/footer.md >> index.md

0_intro.ipynb: snippets/intro.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_python.md snippets/intro.md \
                -o 0_intro.ipynb  
	sed -i 's/attachment://g' 0_intro.ipynb


1_provision_gui.ipynb: snippets/provision_gui.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_bash.md snippets/provision_gui.md \
                -o 1_provision_gui.ipynb  
	sed -i 's/attachment://g' 1_provision_gui.ipynb

2_provision_cli.ipynb: snippets/frontmatter_bash.md snippets/provision_cli.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_bash.md snippets/provision_cli.md \
                -o 2_provision_cli.ipynb  
	sed -i 's/attachment://g' 2_provision_cli.ipynb

3_docker.ipynb: snippets/frontmatter_bash.md snippets/docker.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_bash.md snippets/docker.md \
                -o 3_docker.ipynb  
	sed -i 's/attachment://g' 3_docker.ipynb

4_kubernetes.ipynb: snippets/frontmatter_bash.md snippets/kubernetes.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_bash.md snippets/kubernetes.md \
                -o 4_kubernetes.ipynb  
	sed -i 's/attachment://g' 4_kubernetes.ipynb


5_delete.ipynb: snippets/frontmatter_bash.md snippets/delete.md
	pandoc --resource-path=../ --embed-resources --standalone --wrap=none \
                -i snippets/frontmatter_bash.md snippets/delete.md \
                -o 5_delete.ipynb  
	sed -i 's/attachment://g' 5_delete.ipynb

