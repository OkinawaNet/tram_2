defmodule Tram do
  @moduledoc """
  Модуль `Tram` реализует конечный автомат для управления состояниями трамвая.

  ## Состояния и переходы

  Mermaid:
  idle --> |power_on| ready

  ready --> |open_doors| open
  open --> |close_doors| ready

  ready --> |move| moving
  moving --> |stop| ready

  ready --> |power_off| ready
  ready --> |power_off| final_state

  Описание:

  - `idle` (ожидание)
    - Переход в `ready` (готов) при включении питания (`power_on`).

  - `ready` (готов)
    - Переход в `open` (открытие дверей) при открытии дверей (`open_doors`).
    - Переход в `moving` (движение) при начале движения (`move`).
    - Переход в `final_state` (конечное состояние) при выключении питания (`power_off`), если в трамвае нет пассажиров.
    - Переход в `ready` при выключении питания (`power_off`), если в трамвае есть пассажиры.

  - `open` (открытие дверей)
    - Переход в `ready` при закрытии дверей (`close_doors`).
    - При этом обновляется количество пассажиров в трамвае на основе данных о вошедших и вышедших пассажирах.

  - `moving` (движение)
    - Переход в `ready` при остановке (`stop`).

  """

  use GenServer

  defstruct current: :idle, data: %{passengers: 0}

  # Client

  def start_link() do
    GenServer.start_link(__MODULE__, %__MODULE__{}, name: __MODULE__)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def transition(transition, event_payload \\ %{}) when is_atom(transition) do
    GenServer.call(__MODULE__, {transition, event_payload})
  end

  # Server

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call(:get_state, _, state) do
    {:reply, state, state}
  end

  # Запуск, останов

  def handle_call({:power_on, _}, _, %Tram{current: :idle, data: _} = state) do
    {:reply, {:ok, :ready}, %Tram{state | current: :ready}}
  end

  def handle_call({:power_off, _}, _, %Tram{current: :ready, data: %{passengers: 0}} = state) do
    {:reply, {:ok, :final_state}, %Tram{state | current: :final_state}}
  end

  # Движение

  def handle_call({:move, _}, _, %Tram{current: :ready, data: _} = state) do
    {:reply, {:ok, :moving}, %Tram{state | current: :moving}}
  end

  def handle_call({:stop, _}, _, %Tram{current: :moving, data: _} = state) do
    {:reply, {:ok, :ready}, %Tram{state | current: :ready}}
  end

  # Открытие и закрытие дверей

  def handle_call({:open_doors, _}, _, %Tram{current: :ready, data: _} = state) do
    {:reply, {:ok, :open}, %Tram{state | current: :open}}
  end

  def handle_call(
        {:close_doors, event_payload},
        _,
        %Tram{current: :open, data: data} = state
      ) do
    passengers_entered = Map.get(event_payload, :passengers_entered, 0)
    passengers_exited = Map.get(event_payload, :passengers_exited, 0)

    {:reply, {:ok, :ready},
     %Tram{
       state
       | current: :ready,
         data: update_in(data.passengers, &(&1 + passengers_entered - passengers_exited))
     }}
  end

  # остальное

  def handle_call(_, _, state) do
    {:reply, {:error, :invalid_transition}, state}
  end
end
