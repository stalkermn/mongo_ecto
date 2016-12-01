defmodule MongoEcto.Repo.AutogenerateTest do
    require MongoEcto.Repo, as: TestRepo
    use ExUnit.Case, async: true

    defmodule Account do
        use Ecto.Schema
        use MongoEcto.Model, :model

        @collection_name "accounts"
        @primary_key {:id, :binary_id, autogenerate: true}

        embedded_schema do
            field :nickname, :string
            field :email, :string

            timestamps
        end
    end

    defmodule NoTimestampsAccount do
        use Ecto.Schema
        use MongoEcto.Model, :model

        @collection_name "accounts"
        @primary_key {:id, :binary_id, autogenerate: true}

        embedded_schema do
            field :nickname, :string
            field :email, :string
        end
    end

    setup_all do
        Agent.start_link(fn -> [] end, name: __MODULE__)
        :ok
    end

    setup do
        on_exit fn ->
            inserted = Agent.get_and_update(__MODULE__, &({&1, []}))
            Enum.each inserted, &clean_after_insert/1
        end
    end

    test "`timestamps` fields autogenerates on insert" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {:ok, result} = TestRepo.insert(account)
        register_inserted(result)
        assert match? %Account{inserted_at: %Ecto.DateTime{}}, result
        assert match? %Account{updated_at: %Ecto.DateTime{}}, result
    end

    test "entity contains `timestamps` fields autogenerated by insert" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {:ok, result} = TestRepo.insert(account)
        register_inserted(result)
        entity = TestRepo.get!(Account, result.id)
        assert match? %Account{inserted_at: %Ecto.DateTime{}}, entity
        assert match? %Account{updated_at: %Ecto.DateTime{}}, entity
    end

    test "get_by `timestamps` fields autogenerated by insert" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {:ok, result} = TestRepo.insert(account)
        register_inserted(result)

        query_by_inserted = %{"inserted_at" => ecto_datetime_to_mongo(result.inserted_at)}
        query_by_updated = %{"updated_at" => ecto_datetime_to_mongo(result.updated_at)}
        query_by_inserted_and_updated = Map.merge(query_by_inserted, query_by_updated)

        entity_by_inserted = TestRepo.get_by(Account, query_by_inserted)
        entity_by_updated = TestRepo.get_by(Account, query_by_updated)
        entity_by_inserted_and_updated = TestRepo.get_by(Account, query_by_inserted_and_updated)

        assert match? ^entity_by_inserted, result
        assert match? ^entity_by_updated, result
        assert match? ^entity_by_inserted_and_updated, result
    end

    test "explicit changes rewrite `timestamps` fields" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {{y, m, d}, time} = :calendar.universal_time()
        datetime = Ecto.DateTime.from_erl({{y - 5, m, d}, time})
        changeset = Ecto.Changeset.change(account, %{updated_at: datetime})
        {:ok, result} = TestRepo.insert(changeset)
        register_inserted(result)
        entity = TestRepo.get!(Account, result.id)
        inserted = entity.inserted_at
        updated = entity.updated_at
        assert updated < inserted
        assert updated == datetime
    end

    test "`timestamps` fields autogenerates on update" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {{y, m, d}, time} = :calendar.universal_time()
        datetime = Ecto.DateTime.from_erl({{y - 5, m, d}, time})
        changeset = Ecto.Changeset.change(account, %{updated_at: datetime})
        {:ok, result} = TestRepo.insert(changeset)
        register_inserted(result)
        changeset = Ecto.Changeset.change(result, %{})
        {:ok, result} = TestRepo.update(changeset)
        updated = result.updated_at
        assert updated > datetime
    end

    test "entity contains `timestamps` fields autogenerated by update" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {{y, m, d}, time} = :calendar.universal_time()
        datetime = Ecto.DateTime.from_erl({{y - 5, m, d}, time})
        changeset = Ecto.Changeset.change(account, %{updated_at: datetime})
        {:ok, result} = TestRepo.insert(changeset)
        register_inserted(result)
        inserted_rec = TestRepo.get!(Account, result.id)
        changeset = Ecto.Changeset.change(inserted_rec, %{})
        {:ok, _} = TestRepo.update(changeset)
        result = TestRepo.get!(Account, result.id)
        updated = result.updated_at
        assert updated > datetime
    end

    test "get_by `timestamps` fields autogenerated by update" do
        account = %Account{nickname: "test", email: "test345@gmail.com"}
        {{y, m, d}, time} = :calendar.universal_time()
        datetime = Ecto.DateTime.from_erl({{y - 5, m, d}, time})
        changeset = Ecto.Changeset.change(account, %{updated_at: datetime})
        {:ok, result} = TestRepo.insert(changeset)
        register_inserted(result)

        query_by_updated = %{"updated_at" => ecto_datetime_to_mongo(result.updated_at)}
        entity_by_updated = TestRepo.get_by(Account, query_by_updated)

        assert match? ^entity_by_updated, result
    end

    test "schema without `timestamps` doens't gererate specific fields" do
        account = %NoTimestampsAccount{nickname: "test", email: "test345@gmail.com"}
        {:ok, result} = TestRepo.insert(account)
        register_inserted(result)
        refute match? %{inserted_at: %Ecto.DateTime{}}, result
        refute match? %{updated_at: %Ecto.DateTime{}}, result
    end

    test "entity doesn't have autogenerated fields when schema without `timestamps`" do
        account = %NoTimestampsAccount{nickname: "test", email: "test345@gmail.com"}
        {:ok, result} = TestRepo.insert(account)
        register_inserted(result)
        entity = TestRepo.get!(NoTimestampsAccount, result.id)
        refute match? %{inserted_at: %Ecto.DateTime{}}, entity
        refute match? %{updated_at: %Ecto.DateTime{}}, entity
    end

    defp clean_after_insert(record), do: TestRepo.delete! record

    defp register_inserted(record) do
        Agent.update(__MODULE__, fn list -> [record|list] end)
    end

    defp ecto_datetime_to_mongo(ecto_timestamp = %Ecto.DateTime{}) do
        {:ok, datetime} = Ecto.DateTime.dump(ecto_timestamp)
        BSON.DateTime.from_datetime(datetime)
    end
end
