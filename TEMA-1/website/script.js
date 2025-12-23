(() => {
  function initCarousel(containerId) {
    const projectContainer = document.getElementById(containerId);
    
    if (!projectContainer) return;
    
    const slide = projectContainer.querySelector('.carusel-slide');
    const controls = projectContainer.querySelectorAll('.control-item');
    const kinetocareControls = projectContainer.querySelectorAll('.kinetocare-control');
    const prevBtn = projectContainer.querySelector('.prev');
    const nextBtn = projectContainer.querySelector('.next');
    
    if (!slide || !prevBtn || !nextBtn) return;
    
    let currentIndex = 0;
    const totalSlides = slide.children.length;

    function updateCarousel(index) {
      slide.style.transform = `translateX(-${index * 100}%)`;

      if (controls.length > 0) {
        controls.forEach((control, i) => {
          if (i === index) {
            control.classList.add('active');
          } else {
            control.classList.remove('active');
          }
        });
      }

      if (kinetocareControls.length > 0) {
        kinetocareControls.forEach((control) => {
          const slideIndex = parseInt(control.dataset.slide);
          if (slideIndex === index) {
            control.classList.add('active');
          } else {
            control.classList.remove('active');
          }
        });
      }
      
      currentIndex = index;
    }

    if (controls.length > 0) {
      controls.forEach(control => {
        control.addEventListener('click', () => {
          const slideIndex = parseInt(control.dataset.slide);
          updateCarousel(slideIndex);
        });
      });
    }

    if (kinetocareControls.length > 0) {
      kinetocareControls.forEach(control => {
        control.addEventListener('click', () => {
          const slideIndex = parseInt(control.dataset.slide);
          updateCarousel(slideIndex);
        });
      });
    }

    nextBtn.addEventListener('click', () => {
      let newIndex = (currentIndex + 1) % totalSlides;
      updateCarousel(newIndex);
    });

    prevBtn.addEventListener('click', () => {
      let newIndex = (currentIndex - 1 + totalSlides) % totalSlides;
      updateCarousel(newIndex);
    });
    
    updateCarousel(0);
  }

  initCarousel('kinetocare-project');
  initCarousel('big-data-project');
})();