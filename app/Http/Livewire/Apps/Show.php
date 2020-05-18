<?php

namespace App\Http\Livewire\Apps;

use App\App;
use Illuminate\Foundation\Auth\Access\AuthorizesRequests;
use Livewire\Component;

class Show extends Component
{
    use AuthorizesRequests;

    /** @var \App\App */
    public $app;

    /**
     * @param \App\App $app
     * @return void
     *
     * @throws \Illuminate\Auth\Access\AuthorizationException
     */
    public function mount(App $app)
    {
        $this->authorize('view', $app);

        $this->app = $app;
    }

    /**
     * @return \Illuminate\View\View
     */
    public function render()
    {
        return view('apps.show');
    }
}
