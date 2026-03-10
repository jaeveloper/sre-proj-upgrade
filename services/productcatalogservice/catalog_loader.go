// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"strings"

	"cloud.google.com/go/alloydbconn"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"github.com/Azure/azure-sdk-for-go/sdk/azidentity"
	"github.com/Azure/azure-sdk-for-go/sdk/data/azcosmos"
	pb "github.com/GoogleCloudPlatform/microservices-demo/src/productcatalogservice/genproto"
	"github.com/golang/protobuf/jsonpb"
	"github.com/jackc/pgx/v5/pgxpool"
)

func loadCatalog(catalog *pb.ListProductsResponse) error {
	catalogMutex.Lock()
	defer catalogMutex.Unlock()

	if os.Getenv("COSMOS_ENDPOINT") != "" {
		return loadCatalogFromCosmos(catalog)
	}

	if os.Getenv("ALLOYDB_CLUSTER_NAME") != "" {
		return loadCatalogFromAlloyDB(catalog)
	}

	return loadCatalogFromLocalFile(catalog)
}

// cosmosProduct mirrors the JSON document structure stored in Cosmos DB.
type cosmosProduct struct {
	ID          string      `json:"id"`
	Name        string      `json:"name"`
	Description string      `json:"description"`
	Picture     string      `json:"picture"`
	PriceUSD    cosmosMoney `json:"priceUsd"`
	Categories  []string    `json:"categories"`
}

type cosmosMoney struct {
	CurrencyCode string `json:"currencyCode"`
	Units        int64  `json:"units"`
	Nanos        int32  `json:"nanos"`
}

func loadCatalogFromCosmos(catalog *pb.ListProductsResponse) error {
	endpoint := os.Getenv("COSMOS_ENDPOINT")
	dbName := os.Getenv("COSMOS_DATABASE")
	containerName := os.Getenv("COSMOS_CONTAINER")

	log.Infof("loading catalog from Cosmos DB: endpoint=%s db=%s container=%s", endpoint, dbName, containerName)

	cred, err := azidentity.NewDefaultAzureCredential(nil)
	if err != nil {
		log.Warnf("failed to create Azure credential: %v", err)
		return err
	}

	client, err := azcosmos.NewClient(endpoint, cred, nil)
	if err != nil {
		log.Warnf("failed to create Cosmos DB client: %v", err)
		return err
	}

	container, err := client.NewContainer(dbName, containerName)
	if err != nil {
		log.Warnf("failed to get Cosmos container reference: %v", err)
		return err
	}

	queryPager := container.NewQueryItemsPager(
		"SELECT * FROM c",
		azcosmos.NewPartitionKey(),
		&azcosmos.QueryOptions{QueryParameters: []azcosmos.QueryParameter{}},
	)

	catalog.Products = catalog.Products[:0]
	ctx := context.Background()

	for queryPager.More() {
		page, err := queryPager.NextPage(ctx)
		if err != nil {
			log.Warnf("failed to read Cosmos DB page: %v", err)
			return err
		}

		for _, itemBytes := range page.Items {
			var doc cosmosProduct
			if err := json.Unmarshal(itemBytes, &doc); err != nil {
				log.Warnf("failed to unmarshal Cosmos document: %v", err)
				return err
			}

			product := &pb.Product{
				Id:          doc.ID,
				Name:        doc.Name,
				Description: doc.Description,
				Picture:     doc.Picture,
				PriceUsd: &pb.Money{
					CurrencyCode: doc.PriceUSD.CurrencyCode,
					Units:        doc.PriceUSD.Units,
					Nanos:        doc.PriceUSD.Nanos,
				},
				Categories: doc.Categories,
			}
			catalog.Products = append(catalog.Products, product)
		}
	}

	log.Infof("successfully loaded %d products from Cosmos DB", len(catalog.Products))
	return nil
}

func loadCatalogFromLocalFile(catalog *pb.ListProductsResponse) error {
	log.Info("loading catalog from local products.json file...")

	catalogJSON, err := os.ReadFile("products.json")
	if err != nil {
		log.Warnf("failed to open product catalog json file: %v", err)
		return err
	}

	if err := jsonpb.Unmarshal(bytes.NewReader(catalogJSON), catalog); err != nil {
		log.Warnf("failed to parse the catalog JSON: %v", err)
		return err
	}

	log.Info("successfully parsed product catalog json")
	return nil
}

func getSecretPayload(project, secret, version string) (string, error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		log.Warnf("failed to create SecretManager client: %v", err)
		return "", err
	}
	defer client.Close()

	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: fmt.Sprintf("projects/%s/secrets/%s/versions/%s", project, secret, version),
	}

	// Call the API.
	result, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		log.Warnf("failed to access SecretVersion: %v", err)
		return "", err
	}

	return string(result.Payload.Data), nil
}

func loadCatalogFromAlloyDB(catalog *pb.ListProductsResponse) error {
	log.Info("loading catalog from AlloyDB...")

	projectID := os.Getenv("PROJECT_ID")
	region := os.Getenv("REGION")
	pgClusterName := os.Getenv("ALLOYDB_CLUSTER_NAME")
	pgInstanceName := os.Getenv("ALLOYDB_INSTANCE_NAME")
	pgDatabaseName := os.Getenv("ALLOYDB_DATABASE_NAME")
	pgTableName := os.Getenv("ALLOYDB_TABLE_NAME")
	pgSecretName := os.Getenv("ALLOYDB_SECRET_NAME")

	pgPassword, err := getSecretPayload(projectID, pgSecretName, "latest")
	if err != nil {
		return err
	}

	dialer, err := alloydbconn.NewDialer(context.Background())
	if err != nil {
		log.Warnf("failed to set-up dialer connection: %v", err)
		return err
	}
	cleanup := func() error { return dialer.Close() }
	defer cleanup()

	dsn := fmt.Sprintf(
		"user=%s password=%s dbname=%s sslmode=disable",
		"postgres", pgPassword, pgDatabaseName,
	)

	config, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		log.Warnf("failed to parse DSN config: %v", err)
		return err
	}

	pgInstanceURI := fmt.Sprintf("projects/%s/locations/%s/clusters/%s/instances/%s", projectID, region, pgClusterName, pgInstanceName)
	config.ConnConfig.DialFunc = func(ctx context.Context, _ string, _ string) (net.Conn, error) {
		return dialer.Dial(ctx, pgInstanceURI)
	}

	pool, err := pgxpool.NewWithConfig(context.Background(), config)
	if err != nil {
		log.Warnf("failed to set-up pgx pool: %v", err)
		return err
	}
	defer pool.Close()

	query := "SELECT id, name, description, picture, price_usd_currency_code, price_usd_units, price_usd_nanos, categories FROM " + pgTableName
	rows, err := pool.Query(context.Background(), query)
	if err != nil {
		log.Warnf("failed to query database: %v", err)
		return err
	}
	defer rows.Close()

	catalog.Products = catalog.Products[:0]
	for rows.Next() {
		product := &pb.Product{}
		product.PriceUsd = &pb.Money{}

		var categories string
		err = rows.Scan(&product.Id, &product.Name, &product.Description,
			&product.Picture, &product.PriceUsd.CurrencyCode, &product.PriceUsd.Units,
			&product.PriceUsd.Nanos, &categories)
		if err != nil {
			log.Warnf("failed to scan query result row: %v", err)
			return err
		}
		categories = strings.ToLower(categories)
		product.Categories = strings.Split(categories, ",")

		catalog.Products = append(catalog.Products, product)
	}

	log.Info("successfully parsed product catalog from AlloyDB")
	return nil
}
