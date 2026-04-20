# koillection-facelift
A UI mod for Koillection, collection manager

## Installation 

- Download the latest release package to your local machiene
- copy the contents of dark.css from the ccs directory of the latest release package to the "Custom CSS dark for dark theme" section of your Koillection Administration > Configuration page `https://<your dormain>/admin/configuration`
- copy docker-compose.override.yml and patch-and-start.sh from the docker directory of the latest release package to your koillection docker directory
- restart your koillection container usually  `docker-compose down` then `docker-compose up -d`
- Thats it!
